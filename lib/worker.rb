module Worker
  @queue = :default

  def self.thread_id
    "#{Process.pid}_#{Thread.current.object_id}"
  end
  
  def self.schedule_for(queue, klass, method_name, *args)
    @queue = queue.to_s
    if queue == :slow
      Resque.enqueue(SlowWorker, klass.to_s, method_name, *args)
    else
      Resque.enqueue(Worker, klass.to_s, method_name, *args)
    end
  end
  
  def self.schedule(klass, method_name, *args)
    schedule_for(:default, klass, method_name, *args)
  end
  
  def self.perform(*args)
    perform_at(:normal, *args)
  end
  
  def self.ts
    Time.now.to_i
  end
  
  def self.perform_at(speed, *args)
    args_copy = [] + args
    klass_string = args_copy.shift
    klass = Object.const_get(klass_string)
    method_name = args_copy.shift
    hash = args_copy[0] if args_copy[0].is_a?(Hash)
    hash ||= {'method' => method_name}
    action = "#{klass_string} . #{hash['method']} (#{hash['id']})"
    pre_whodunnit = PaperTrail.whodunnit
    PaperTrail.whodunnit = "job:#{action}"
    Rails.logger.info("performing #{action}")
    start = self.ts
    klass.send(method_name, *args_copy)
    diff = self.ts - start
    Rails.logger.info("done performing #{action}, finished in #{diff}s")
    # TODO: way to track what queue a job is coming from
    if diff > 60 && speed == :normal
      Rails.logger.error("long-running job, #{action}, #{diff}s")
    elsif diff > 60*10 && speed == :slow
      Rails.logger.error("long-running job, #{action} (expected slow), #{diff}s")
    end
    PaperTrail.whodunnit = pre_whodunnit
  rescue Resque::TermException
    Resque.enqueue(self, *args)
  end
  
  def self.on_failure_retry(e, *args)
    # TODO...
  end
  
  def self.scheduled_actions(queue='default')
    queues = [queue]
    if queue == '*'
      queues = []
      Resque.queues.each do |key|
        queues << key
      end
    end

    res = []
    queues.each do |queue|
      idx = Resque.size(queue)
      idx.times do |i|
        res << Resque.peek(queue, i)
      end
    end
    res
  end
  
  def self.scheduled_for?(queue, klass, method_name, *args)
    idx = Resque.size(queue)
    queue_class = (queue == :slow ? 'SlowWorker' : 'Worker')
    idx.times do |i|
      schedule = Resque.peek(queue, i)
      if schedule && schedule['class'] == queue_class && schedule['args'][0] == klass.to_s && schedule['args'][1] == method_name.to_s
        if args.to_json == schedule['args'][2..-1].to_json
          return true
        end
      end
    end
    return false
  end
  
  def self.scheduled?(klass, method_name, *args)
    scheduled_for?('default', klass, method_name, *args)
  end
  
  def self.stop_stuck_workers
    timeout = 8.hours.to_i
    Resque.workers.each {|w| w.unregister_worker if w.processing['run_at'] && Time.now - w.processing['run_at'].to_time > timeout}    
  end
  
  def self.prune_dead_workers
    Resque.workers.each{|w| w.prune_dead_workers }
  end
  
  def self.kill_all_workers
    Resque.workers.each{|w| w.unregister_worker }
  end
  
  def self.process_queues
    schedules = []
    Resque.queues.each do |key|
      while Resque.size(key) > 0
        schedules << {queue: key, action: Resque.pop(key)}
      end
    end
    schedules.each do |schedule|
      queue = schedule[:queue]
      schedule  = schedule[:action]
      if queue == 'slow'
        raise "unknown job: #{schedule.to_json}" if schedule['class'] != 'SlowWorker'
        SlowWorker.perform(*(schedule['args']))
      else
        raise "unknown job: #{schedule.to_json}" if schedule['class'] != 'Worker'
        Worker.perform(*(schedule['args']))
      end
    end
  end
  
  def self.queues_empty?
    found = false
    Resque.queues.each do |key|
      return false if Resque.size(key) > 0
    end
    true
  end
  
  def self.flush_queues
    if Resque.redis
      Resque.queues.each do |key|
        Resque.redis.ltrim("queue:#{key}", 1, 0)
      end
    end
  end
end