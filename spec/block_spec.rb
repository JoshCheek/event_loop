require 'event_loop/block'

# these tests pass, if test suite doesn't lock up or deadlock :/
RSpec.describe EventLoop::Block do
  specify '#block wil block until #unblock is called' do
    block  = described_class.new
    thread = Thread.new { block.block }
    loop { break if thread.status == 'sleep' }
    block.unblock
    thread.join
  end

  specify 'unblocks immediately if unblock is called before block' do
    block = described_class.new
    block.unblock
    block.block
  end
end
