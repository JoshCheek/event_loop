Initial intent
--------------

Wanted to play with some JavaScript style async ideas.
This is what I think an Event Loop might look like, based on how it seems to behave.

Idea would be that you could write synchronous code, and when you hit async points,
JS could see you're making an async call, and take your current stack of execution
and place it onto the event loop as the callback.

In other words, you write normal synchronous code, it runs async.
You don't have to pollute it with promises and crap like that.
See "Event Loop" below to see how far I got.


What kinda actually happened
----------------------------

My first time really getting into threads and that sort of thing, so lots of ideas occurred to me,
and lots of pain points were obvious to me, so instead I wound up building some lower level
code to aid working with this kind of idea.


### Fixed RSpec `#let` blocks to be async

PR is [here](https://github.com/rspec/rspec-core/pull/1858).
Still not merged, I have to make another benchmark.

### Worker

A background worker that can be turned on and off.
If it is off, it finishes its current task, then blocks until you turn it on again.
If it is on, it pulls from a work queue, and then performs the work.

```ruby
require "event_loop/worker.rb"

start_time = Time.now
offset     = -> { sprintf '%0.1fsec', Time.now - start_time }
work       = Queue.new

worker = EventLoop::Worker.new work do |result|
  [offset.call, result]
  # => ["0.0sec", :res1]
  #    ,["0.0sec", :res2]
  #    ,["2.0sec", :res3]
  #    ,["2.0sec", :res4]
  #    ,["2.0sec", :res5]
  #    ,["2.0sec", :res6]
end



# 2 immediate results, one after 0.05s
worker.on!
work << :res1
work << :res2
sleep 1
work << :res3

# same thing, but turn the worker off while we do it
worker.off!
work << :res4
work << :res5
sleep 1
work << :res6

# now we will turn it on, the events will all come through at the same time
worker.on!

Thread.pass until worker.waiting?

# it has processsed all the work, it is waiting on more to be placed in the queue
worker.waiting? # => true
worker.off!
```

The states of the worker

```ruby
# it is resting when it is turned off and it has finished its current task
worker.resting? # => false

# it is waiting when it is ready to do work, but the queue is empty
worker.waiting? # => true

# it is working when it's pulled an item out of the queue and is executing the block
worker.working? # => false
```


### Switch

Switch has a state of either `blocked` or `unblocked`.
Any thread which calls `Switch#wait` will block until some other thread
calls `Switch#unblock`

Example

```ruby
switch = Switch.new :blocked
result = nil
invoke_something_asynchronously do |r|
  result = r
  switch.unblock
end

switch.wait

# do something with result
```


Wait
----

Doesn't work. Just a thought about how it might be nice to be able to control which threads are running when.
IDK if this is actually useful, it sort of defeats the purpose of using threads. It was just an experiment.


Event Loop
----------

Doesn't work. Might eventually come finish this. Its job is to be an event look like JavaScript has,
for the purpose of allowing me to show how the code could be rewritten and run correctly.

I Initially tried in JavaScript, but the rewriter wasn't good enough to handle
the AST change that I wanted https://gist.github.com/JoshCheek/47c3fb69640202ec72c7

So I decided to try in Ruby.

The code transformation needs to look like this, I think
```ruby
# Given this code
def call(var)
  var
end

a = 0
a = call b
a + 1

----

# Translate it at runtime into this code
def call(var, async)
  async.call var
end

a = 0
call b, -> result {
  a = result
  a + 1
}
```

I hadn't gotten to the point of doing the rewrite, because I got side tracked
with the Event Loop, but this was the example I was trying to work with.


```ruby
require 'parser/current'

raw_code = <<CODE
def sleep_blocking(seconds)
  sleep seconds
  :sleep_blocking_result
end

def sleep_async(seconds) # async!
  sleep seconds
  :sleep_async_result
end

blocking_result1 = sleep_blocking 1
async_result1    = sleep_async    1 # async!
blocking_result2 = sleep_blocking 1
async_result12   = sleep_async    1 # async!

puts "Blocking1 returned: \#{blocking_result1.inspect}"
puts "Async1 returned:    \#{async_result1   .inspect}"
puts "Blocking2 returned: \#{blocking_result2.inspect}"
puts "Async2 returned:    \#{async_result2   .inspect}"
CODE


buffer             = Parser::Source::Buffer.new("sync_to_async")
buffer.source      = raw_code
builder            = Parser::Builders::Default.new
rewriter           = Parser::Source::Rewriter.new buffer
parser             = Parser::CurrentRuby.new builder
root_ast, comments = parser.parse_with_comments buffer

# tell it where we depend on the result
async_lines = comments.select { |c| c.text == '# async!' }.map { |c| c.loc.line }

# transformation code needs to go here
root_ast
```


License
-------

WTFPL http://wtfpl.net/about
