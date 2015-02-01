require 'thread'

class EventLoop
  class Switch
    def initialize(initial_state)
      states = [:blocked, :unblocked]
      states.include? initial_state or
        raise ArgumentError, "Unknown initial state: #{initial_state}, expected one of #{states.inspect}"
      self.state       = initial_state
      self.queue       = Queue.new
      self.semaphore   = Mutex.new
      self.num_blocked = 0
    end

    attr_reader :state, :num_blocked

    def blocked?
      state == :blocked
    end

    def unblocked?
      state == :unblocked
    end

    def wait
      semaphore.synchronize do
        return if unblocked?
        @num_blocked += 1
      end
      queue.shift
      nil
    end

    def block
      semaphore.synchronize { self.state = :blocked }
      :blocked
    end

    def unblock
      semaphore.synchronize do
        if blocked?
          self.state = :unblocked
          num_blocked.times { queue << nil }
          self.num_blocked = 0
        end
      end
      :unblocked
    end

    def inspect
      "#<Switch state: #{state}, num_blocked: #{num_blocked}>"
    end

    private

    attr_writer :state, :num_blocked
    attr_accessor :queue, :semaphore
  end
end
