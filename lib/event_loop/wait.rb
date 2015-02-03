# Wait.until { 1 == 2 }
# Wanderer, like Turn, but does not return

class Enroll
  def initialize
    @current_turn = :no_current_turn
    @turn_classes = []
    @mutex = Mutex.new
    @mutex.lock
  end

  def enroll(name, messages: [], &block)
    turn_class = register_turn name, messages
    loop do
      wait_for_turn turn_class do
        puts "Taking turn #{@current_turn.inspect}"
        block.call @current_turn
        @current_turn.done
        puts "done #{name}"
        if @current_turn.unenroll?
          unregister_turn turn_class
          puts "unregistered #{name}"
          return
        end
      end
    end
  rescue
    puts "ERROR: #$!"
    puts $!.backtrace
  end

  def call(name, message)
    @current_turn = turn_for name, message
    loop do
      puts "calling #{name}"
      @mutex.unlock
      Thread.pass
      @mutex.lock
      break if @current_turn.done?
      puts "recalling #{name}"
    end
    puts "done with #{name}"
    @current_turn = :no_current_turn
  end

  private

  class TurnClass
    def self.build(name, allowed_messages)
      Class.new self do
        @name = name
        @allowed_messages = allowed_messages.freeze
        allowed_messages.each do |message_name|
          define_method("#{message_name}?") { @message == message_name }
        end
      end
    end

    def self.name
      @name
    end

    def self.allowed_messages
      @allowed_messages
    end

    def initialize(message)
      @message  = message
      @done     = false
      @unenroll = false
    end

    def done
      @done = true
    end

    def done?
      @done
    end

    def unenroll?
      @unenroll
    end

    def unenroll
      @unenroll = true
    end
  end

  def register_turn(name, allowed_messages)
    klass = @turn_classes.find { |k| k.name == name && k.allowed_messages == allowed_messages }
    klass ||= TurnClass.build(name, allowed_messages)
    @turn_classes << klass
    klass
  end

  def unregister_turn(turn_class)
    @turn_classes.delete turn_class
  end

  def turn_for(name, message)
    loop do
      klass = @turn_classes.find do |klass|
        klass.name == name &&
          klass.allowed_messages.include?(message)
      end
      return klass.new(message) if klass
      @mutex.unlock
      Thread.pass
      @mutex.lock
    end
  end

  # tail call would be nice
  def wait_for_turn(turn_class, &block)
    loop do
      @mutex.lock
      break if @current_turn.is_a? turn_class
      @mutex.unlock
      Thread.pass
    end
    block.call # <-- that could raise
    @mutex.unlock
  end
end


enroll = Enroll.new
ary    = []

t1 = Thread.new do
  enroll.enroll :t1, messages: [:break, :append] do |turn|
    puts "in t1"
    puts "turn.break? #{turn.break?}"
    puts "turn.append? #{turn.append?}"
    turn.unenroll if turn.break?
    ary << :t1    if turn.append?
    puts "now returning"
  end
end

t2 = Thread.new do
  enroll.enroll :t2, messages: [:break, :append] do |turn|
    puts "in t2"
    puts "turn.break? #{turn.break?}"
    puts "turn.append? #{turn.append?}"
    turn.unenroll if turn.break?
    ary << :t2    if turn.append?
    puts "now returning"
  end
end

Thread.pass

3.times {
  enroll.call :t1, :append
}
4.times {
  enroll.call :t2, :append
}
5.times {
  enroll.call :t1, :append
  enroll.call :t2, :append
}
enroll.call :t1, :break
enroll.call :t2, :break

expected = [
  :t1, :t1, :t1,
  :t2, :t2, :t2, :t2,
  :t1, :t2,
  :t1, :t2,
  :t1, :t2,
  :t1, :t2,
  :t1, :t2,
]
p expected
p ary
