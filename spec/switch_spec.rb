require 'event_loop/switch'

# these tests pass, if test suite doesn't lock up or deadlock :/
RSpec.describe EventLoop::Switch do
  it 'blows up if initialized with an unknown initial sttaus' do
    described_class.new :unblocked
    described_class.new :blocked
    expect { described_class.new :wat }.to raise_error ArgumentError
  end

  it 'knows what state its in' do
    switch = described_class.new :unblocked

    switch.block
    expect(switch).to     be_blocked
    expect(switch).to_not be_unblocked
    expect(switch.state).to eq :blocked

    switch.unblock
    expect(switch).to_not be_blocked
    expect(switch).to     be_unblocked
    expect(switch.state).to eq :unblocked
  end

  specify 'wait returns nil' do
    switch = described_class.new :unblocked
    expect(switch.wait).to eq nil
    switch.block
    t = Thread.new { expect(switch.wait).to eq nil }
    loop do
      break if t.status == 'sleep'
      sleep 0.01
    end
    switch.unblock
    t.join
  end

  specify 'block returns :blocked, unblock returns :unblocked' do
    switch = described_class.new :blocked
    expect(switch.block).to eq :blocked
    expect(switch.unblock).to eq :unblocked
    expect(switch.unblock).to eq :unblocked
    expect(switch.block).to eq :blocked
  end

  specify 'when it is unblocked, #block will always return immediately' do
    switch = described_class.new :unblocked
    switch.wait
    switch.wait
    switch.wait
  end

  specify 'when it is blocked, #unblock will release any blocking' do
    switch = described_class.new :blocked
    threads = 5.times.map { Thread.new { switch.wait } }
    loop do
      break if threads.map(&:status) == ['sleep']*5
      sleep 0.01
    end
    switch.unblock
    threads.each &:join
  end

  specify 'blocking can be switched on and off with #block and #unblock' do
    switch = described_class.new :blocked

    # wait does nothing when unblocked
    switch.unblock
    switch.wait
    switch.wait

    # wait sleeps thread when blocked
    switch.block
    thread = Thread.new { switch.wait }
    loop do
      break if thread.status == 'sleep'
      sleep 0.01
    end
    switch.unblock
    thread.join

    # now that it is unblocked, waits do nothing again
    switch.wait
    switch.wait
  end

  it 'knows how many threads are currently blocked' do
    switch = described_class.new :unblocked

    switch.wait
    switch.wait
    expect(switch.num_blocked).to eq 0

    switch.block
    threads = 3.times.map { Thread.new { switch.wait } }
    loop do
      break if threads.map(&:status) == ['sleep']*3
      sleep 0.01
    end
    expect(switch.num_blocked).to eq 3
    switch.unblock
    expect(switch.num_blocked).to eq 0

    switch.wait
    switch.wait
    expect(switch.num_blocked).to eq 0
  end
end
