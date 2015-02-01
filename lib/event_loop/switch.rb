class EventLoop
  class Switch
    def initialize(initial_state)
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
      return nil if unblocked?
      semaphore.synchronize { @num_blocked += 1 }
      queue.shift
      nil
    end

    def block
      self.state = :blocked
      :blocked
    end

    def unblock
      return :unblocked if unblocked?
      semaphore.synchronize do
        self.state = :unblocked
        num_blocked.times { queue << nil }
        self.num_blocked = 0
      end
      :unblocked
    end

    private

    attr_writer :state, :num_blocked
    attr_accessor :queue, :semaphore

    def states
      @states ||= [:blocked, :unblocked]
    end
  end
end
