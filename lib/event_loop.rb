require 'thread'

class EventLoop
  Work = Struct.new :job, :callback, :result

  def initialize(num_workers)
    self.num_workers = num_workers
    self.work_queue  = Queue.new
    self.event_queue = Queue.new
    self.workers     = num_workers.times.map { Thread.new { create_worker } }
    self.event_loop  = Thread.new { create_event_loop }
  end

  def async(work, callback)
    work_queue << Work.new(work, callback)
    nil
  end

  def shutdown
    num_workers.times { work_queue << :shutdown }
    event_queue << :shutdown
  end

  def join
    workers.each(&:join)
    event_loop.join
  end

  private

  attr_accessor :num_workers, :work_queue, :event_queue, :workers, :event_loop

  def create_event_loop
    loop do
      work = event_queue.shift
      puts "EVENT: #{work.inspect}"
      break if :shutdown == work
      begin
        work.callback.call work.result
      rescue Exception => e
        puts "Callback exception: #{e.inspect} for #{work.inspect}"
      end
    end
  end

  def create_worker
    loop do
      work = @work_queue.shift
      puts "WORK: #{work.inspect}"
      break if :shutdown == work
      begin
        work.result = work.job.call
      rescue Exception => e
        puts "Work exception: #{e.inspect} for #{work.inspect}"
      end
      event_queue << work
    end
  end
end

event_loop = EventLoop.new 3
define_method :sleep_async do |seconds, callback|
  event_loop.async -> { sleep seconds }, callback
end

work = -> {
  start_time = Time.now
  sleep_async(1, -> first_value {
    Time.now - start_time
    sleep_async(2, -> second_value {
      Time.now - start_time
      first_value + second_value
    })
    Time.now - start_time
  })
  Time.now - start_time
}

time = Time.now
event_loop.async work, ->
event_loop.join
Time.now - time










