class EventLoop
  class Block
    def initialize
      @queue = Queue.new
    end

    def block
      @queue.shift
    end

    def unblock
      @queue << :unblock
    end
  end
end
