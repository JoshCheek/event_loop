class EventLoop
  class Switch
    def initialize(initial_state)
      unless states.include? initial_state
        raise ArgumentError, "Unknown initial state: #{initial_state}, expected one of #{states.inspect}"
      end
      self.state = initial_state
      self.queue = Queue.new
      self.num_blocked = 0 # this might be mutex territory
    end

    attr_reader :state, :num_blocked

    def wait
      return nil if unblocked?
      @num_blocked += 1
      queue.shift
      nil
    end

    def block
      self.state = :blocked
      :blocked
    end

    def blocked?
      state == :blocked
    end

    def unblock
      return :unblocked if unblocked?
      self.state = :unblocked
      num_blocked = @num_blocked
      @num_blocked = 0
      num_blocked.times { queue << nil }
      :unblocked
    end

    def unblocked?
      state == :unblocked
    end

    private

    attr_writer :state, :num_blocked
    attr_accessor :queue

    def states
      @states ||= [:blocked, :unblocked]
    end
  end
end
