module JsonApi::Sound
  extend JsonApi::Json
  
  TYPE_KEY = 'sound'
  DEFAULT_PAGE = 25
  MAX_PAGE = 50
    
  def self.build_json(sound, args={})
    json = {}
    json['id'] = sound.global_id
    json['url'] = sound.url
    ['pending', 'content_type', 'duration'].each do |key|
      json[key] = sound.settings[key]
    end
    json['license'] = OBF::Utils.parse_license(sound.settings['license'])
    if (args[:data] || !sound.url) && sound.data
      json['url'] = sound.data
    end
    if args[:permissions]
      json['permissions'] = sound.permissions_for(args[:permissions])
    end
    json
  end
  
  def self.meta(sound)
    json = {}
    if sound.pending_upload?
      params = sound.remote_upload_params
      json = {'remote_upload' => params}
    end
    json
  end
end