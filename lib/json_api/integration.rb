module JsonApi::Integration
  extend JsonApi::Json
  
  TYPE_KEY = 'integration'
  DEFAULT_PAGE = 10
  MAX_PAGE = 25
    
  def self.build_json(obj, args={})
    json = {}
    # TODO: include devices
    
    json['id'] = obj.global_id
    json['name'] = obj.settings['name']
    json['custom_integration'] = !!obj.settings['custom_integration']
    
    if obj.settings['custom_integration']
      device_token = obj.device.token
      if obj.created_at > 24.hours.ago && obj.device
        json['access_token'] = device_token
        json['token'] = obj.settings['token']
      end
      json['truncated_access_token'] = "...#{device_token[-5, 5]}"
      json['truncated_token'] = "...#{obj.settings['token'][-5, 5]}"
    end

    json
  end
end
