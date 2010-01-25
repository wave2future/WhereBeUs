import logging
import datetime

from django.conf import settings

from google.appengine.ext import db
from .utils import get_rid_of_microseconds, iso_utc_string, chunk_sequence

class UserService(db.Model):
    KNOWN_SERVICE_TYPES = ['twitter', 'facebook']

    # Stuff provided to us by the client
    screen_name = db.StringProperty()               # dangerdave
    display_name = db.StringProperty()              # Dave Peck
    profile_image_url = db.LinkProperty()           # http://.../foo.jpg
    large_profile_image_url = db.LinkProperty()     # http://.../big-foo.jpg
    service_url = db.LinkProperty()                 # http://twitter.com/dangerdave/
    service_type = db.StringProperty()              # twitter 
    id_on_service = db.IntegerProperty()            # 12345 (together means entity's key_name is "twitter-12345")
    message = db.StringProperty()                   # On my way to DRINK LOTS OF BEER!
    location = db.GeoPtProperty()                   # (0, 0)
    
    # Stuff automatically generated by the server
    update_guid = db.StringProperty()               # If user is logged in on both FB and Twitter, this will be the same for both UserService objects...
    update_time = db.DateTimeProperty()             # When did our last successful update happen?
    message_time = db.DateTimeProperty()            # When did the user's message most recently change?
    index_count = db.IntegerProperty()              # How many UserServiceIndex objects do we have?
        
    @staticmethod
    def key_name_for_service_and_id(service_type, id_on_service):
        return '%s-%s' % (service_type, str(id_on_service))
    
    @staticmethod
    def get_for_service_and_id(service_type, id_on_service):
        key_name = UserService.key_name_for_service_and_id(service_type, id_on_service)
        return UserService.get_by_key_name(key_name)
    
    @staticmethod
    def get_or_insert_for_service_and_id(service_type, id_on_service):
        if service_type not in UserService.KNOWN_SERVICE_TYPES:
            raise Exception("Invalid service_type")
        key_name = UserService.key_name_for_service_and_id(service_type, id_on_service)
        user_service = UserService.get_or_insert(key_name = key_name)
        user_service.service_type = service_type
        user_service.id_on_service = id_on_service
        return user_service
        
    def following(self):
        user_service_index_keys = db.GqlQuery("SELECT __key__ FROM UserServiceIndex WHERE follower_key_names = :1", self.key().name())
        user_service_keys = [user_service_index_key.parent() for user_service_index_key in user_service_index_keys]
        return db.get(user_service_keys)
        
    def has_recent_message(self, request_time):
        return (self.message) and ((request_time - self.message_time) <= settings.TIME_HORIZON)
        
    def update(self, request_time):
        if (self.location is None) or (self.location.lat == 0.0 and self.location.lon == 0.0):
            return None
        if (request_time - self.update_time) > settings.TIME_HORIZON:
            return None      
        has_recent_message = self.has_recent_message(request_time)  
        return {
            "screen_name": self.screen_name,
            "display_name": self.display_name,
            "profile_image_url": self.profile_image_url,
            "large_profile_image_url": self.large_profile_image_url,
            "latitude": self.location.lat,
            "longitude": self.location.lon,
            "update_time": iso_utc_string(self.update_time),
            "message": self.message if has_recent_message else "",
            "message_time": iso_utc_string(self.message_time) if has_recent_message else None,
            "service_type": self.service_type,
            "service_url": self.service_url,
            "id_on_service": self.id_on_service,
        }
        
    def set_followers(self, follower_ids):
        follower_key_names = [UserService.key_name_for_service_and_id(self.service_type, follower_id) for follower_id in follower_ids]
        if self.index_count > 0:
            old_index_keys = [db.Key.from_path('UserService', self.key().name(), 'UserServiceIndex', "index-%d" % i) for i in range(self.index_count)]
            db.delete(old_index_keys)
        self.index_count = 0
        user_service_indexes = []
        for follower_key_names_chunk in chunk_sequence(follower_key_names, UserServiceIndex.MAX_FOLLOWERS):
            user_service_index = UserServiceIndex(key_name = "index-%d" % self.index_count, parent = self, follower_key_names = follower_key_names_chunk)
            user_service_indexes.append(user_service_index)
            self.index_count = self.index_count + 1
        db.put(user_service_indexes)
    
    @staticmethod
    def unique_following(user_services):
        followings = []
        for user_service in user_services:
            followings.extend(user_service.following())
            
        seen = {}
        for following in followings:
            if (following.update_guid not in seen) or (following.service_type == "twitter"):
                seen[following.update_guid] = following
        return seen.values()
        
    @staticmethod
    def iter_updates_for_user_services(user_services, request_time):
        unique_services = UserService.unique_following(user_services)
        for unique_service in unique_services:
            update = unique_service.update(request_time)
            if update is not None:
                yield update
    
    @staticmethod
    def updates_for_user_services(user_services, request_time):
        return [update for update in UserService.iter_updates_for_user_services(user_services, request_time)]

class UserServiceIndex(db.Model):
    # The key for this entity is always a child of a UserService
    MAX_FOLLOWERS = 2000
    follower_key_names = db.StringListProperty() 
