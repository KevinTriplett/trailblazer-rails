require 'test_helper'
require 'spec/spec_helper'

class SongOperationTest < MiniTest::Spec
  class Create < Trailblazer::Operation
    class MyTransaction
      def self.call((ctx, flow_options), *, &block)
        ActiveRecord.transaction do
          signal, (ctx, flow_options) = yield
          ctx[:model].save if ctx[:model]
          raise ActiveRecord::Rollback unless signal
        end
      rescue
        [ Trailblazer::Operation::Railway.fail!, [ctx, flow_options] ]
      end
    end

    step Wrap( MyTransaction ) {
      step :before
      step :persist
      step :after
    }

    def before(ctx, **)
      ctx[:before_signal]
    end

    def persist(ctx, **)
      ctx[:persist_signal]
    end

    def after(ctx, **)
      ctx[:after_signal]
    end
  end

  it "is happy when all steps succeed" do
    result = Create.(before_signal: true, persist_signal: true, after_signal: true)
    assert result.success?
  end

  it "it fails when :before step fails" do
    result = Create.(before_signal: false, persist_signal: true, after_signal: true)
    assert !result.success?
  end

  it "it fails when persist: step fails" do
    result = Create.(before_signal: true, persist_signal: false, after_signal: true)
    assert !result.success?
  end

  it "it fails when after: step fails" do
    result = Create.(before_signal: true, persist_signal: true, after_signal: false)
    assert !result.success?
  end

  it "does not save song record on failures" do
    new_song = Song.new(title: "Begin the Beguine")
    result = Create.(model: new_song, before_signal: true, persist_signal: true, after_signal: true)
    assert result[:model].id

    result = Create.(model: new_song, before_signal: false, persist_signal: true, after_signal: true)
    assert !result[:model].id

    result = Create.(model: new_song, before_signal: true, persist_signal: false, after_signal: true)
    assert !result[:model].id

    result = Create.(model: new_song, before_signal: true, persist_signal: true, after_signal: false)
    assert !result[:model].id
  end
end