require 'event_loop/worker'
require 'event_loop/switch'
require 'timeout'

RSpec.describe EventLoop::Worker do
  # Must use let! b/c let is lazy and is not threadsafe
  # A lot of hours went into figuring that out :/
  let!(:queue)     { Queue.new }
  let!(:parent)    { EventLoop::Switch.new :blocked }
  let!(:child)     { EventLoop::Switch.new :blocked }

  def new_worker(queue, &job)
    described_class.new(queue, &job)
  end

  def is_resting!(worker)
    Timeout.timeout 0.5 do
      loop { worker.resting? ? break : sleep(0.01) }
    end
  end

  def is_waiting!(worker)
    Timeout.timeout 0.5 do
      loop { worker.waiting? ? break : sleep(0.01) }
    end
  end

  it 'is off by default and resting by default' do
    worker = new_worker(queue) { }
    expect(worker).to be_off
    expect(worker).to be_resting
  end

  it 'is only ever off or on, never both' do
    worker = new_worker(queue) { }
    worker.off!
    expect(worker).to be_off
    expect(worker).to_not be_on
    worker.on!
    expect(worker).to be_on
    expect(worker).to_not be_off
  end

  it 'returns itself when told to turn on or off so you can append them to the constructor' do
    worker = new_worker(queue) { }
    expect(worker.off!).to equal worker
    expect(worker.on!).to  equal worker
  end

  it 'is only ever waiting, working, or resting never more than one' do
    worker = new_worker(queue) {
      parent.unblock
      child.wait
    }
    worker.off!
    queue << :item
    is_resting! worker
    expect(worker).to     be_resting
    expect(worker).to_not be_waiting
    expect(worker).to_not be_working

    worker.on!
    parent.wait
    expect(worker).to_not be_resting
    expect(worker).to_not be_waiting
    expect(worker).to     be_working
    child.unblock

    is_waiting! worker
    expect(worker).to_not be_resting
    expect(worker).to     be_waiting
    expect(worker).to_not be_working
  end

  # Uhm, errors are harder than I thought
  # I'm not sure what the right thing to do is, maybe abort on exception,
  # but that seems very hard to rescue
  # Maybe provide a callabck to handle errors.
  xit 'errors in the block are raised up, they do not prevent it from operating' do
    seen = []
    worker = new_worker(queue) { |item|
      raise "omg!"
      seen << Thread.current
    }.on!
    expect {
      queue << 1
      loop { break if seen.any?; sleep 0.01 }
      seen.first.raise(Exception, "zomg!")
    }.to raise_error /zomg/
    queue << :unblock
    parent.wait
    expect(seen).to eq [:first, :raise, :unblock]
  end

  context 'when I turn it on' do
    it 'is on and is not resting' do
      worker = new_worker(queue) { }.on!
      expect(worker).to be_on
      is_waiting! worker
    end

    it 'pulls work from the queue and hands it to the job to perform' do
      performed = []
      worker = new_worker(queue) { |item|
        performed << item * 2
        parent.unblock
      }.on!
      expect(performed).to be_empty
      queue << 6
      parent.wait
      expect(performed).to eq [12]
    end

    it 'is waiting when it asks for items from an empty queue' do
      worker = new_worker(queue) { |item| }.on!
      queue << :item
      is_waiting! worker
    end

    it 'is working while it performs the job' do
      queue << :work
      worker = new_worker(queue) { |item|
        parent.unblock
        child.wait
      }.on!
      parent.wait
      expect(worker).to be_working
    end
  end

  context 'when it is off' do
    context 'and it is waiting for work' do
      it 'finishes waiting, then rests instead of performing the work, but resumes when I turn it on again' do
        performed = []
        worker = new_worker(queue) do |item|
          performed << item
          parent.unblock
        end
        # it is waiting for work, but is turned off
        worker.on!
        is_waiting! worker
        worker.off!

        # give it work, it will rest instead of doing the work
        queue << :item
        is_resting! worker
        expect(performed).to be_empty

        # turn it on, it will do the work, we will wait for the work to be done
        worker.on!
        parent.wait
        expect(performed).to eq [:item]
      end
    end
    context 'and it is doing work' do
      it 'finishes the work, then rests instead of waiting for new work, but resumes when I turn it on again' do
        worker = new_worker(queue) do |item|
          parent.unblock
          child.wait
        end.on!
        queue << :item

        # initial state: off and working
        parent.wait
        worker.off!
        expect(worker).to be_off
        expect(worker).to be_working

        # finish working, rests since it is off
        child.unblock
        is_resting! worker
        expect(worker).to be_off
        expect(worker).to be_resting

        # turn it on, it is waiting for work
        worker.on!
        is_waiting! worker
        expect(worker).to be_on
        expect(worker).to be_waiting
      end
    end
    context 'and I turn it off' do
      it 'remains off, but still turns on again' do
        performed = []
        worker = new_worker(queue) do |item|
          performed << item
          parent.unblock
        end
        worker.off!
        queue << :item
        is_resting! worker
        expect(worker).to be_off
        worker.off!
        worker.on!
        parent.wait
        expect(worker).to be_on
        expect(performed).to eq [:item]
      end
    end
  end
end
