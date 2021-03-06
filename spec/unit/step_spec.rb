RSpec.describe Dry::Transaction::Step do
  let(:step_adapter) { ->(step, input, *args) { step.operation.call(input, *args) } }
  let(:step_name) { :test }
  let(:operation_name) { step_name }

  subject(:step) { described_class.new(step_adapter, step_name, operation_name, operation, {}) }

  describe "#call" do
    let(:listener) do
      Class.new do
        def step_called(step_name, *args); end
        def step_succeeded(step_name, *args); end
        def step_failed(step_name, *args, value); end
      end.new
    end

    let(:input) { "input" }
    subject { step.call(input) }

    context "when operation succeeds" do
      let(:operation) { proc { |input| Dry::Monads::Result::Success.new(input) } }

      it { is_expected.to be_right }

      it "publishes step_succeeded" do
        expect(listener).to receive(:step_succeeded).with(step_name, "input")
        step.subscribe(listener)
        subject
      end
    end

    context "when operation starts" do
      let(:operation) { proc { |input| Dry::Monads::Either::Right.new(input) } }

      it "publishes step_called" do
        expect(listener).to receive(:step_called).with(step_name, input)
        step.subscribe(listener)
        subject
      end
    end

    context "when operation fails" do
      let(:operation) { proc { |input| Dry::Monads::Result::Failure.new("error") } }

      it { is_expected.to be_left }

      it "wraps value in StepFailure" do
        aggregate_failures do
          expect(subject.left).to be_a Dry::Transaction::StepFailure
          expect(subject.left.value).to eq "error"
        end
      end

      it "publishes step_failed" do
        expect(listener).to receive(:step_failed).with(step_name, input, "error")
        step.subscribe(listener)
        subject
      end
    end
  end

  describe "#with" do
    let(:operation) { proc { |a, b| a + b } }
    context "without arguments" do
      it "returns itself" do
        expect(step.with).to eq step
      end
    end

    context "with operation argument" do
      it "returns new instance with only operation changed" do
        new_operation = proc { |a,b| a * b }
        new_step = step.with(operation: new_operation)
        expect(new_step).to_not eq step
        expect(new_step.operation_name).to eq step.operation_name
        expect(new_step.operation).to_not eq step.operation
      end
    end

    context "with call_args argument" do
      let(:call_args) { [12] }
      it "returns new instance with only call_args changed" do
        new_step = step.with(call_args: call_args)
        expect(new_step).to_not eq step
        expect(new_step.operation_name).to eq step.operation_name
        expect(new_step.call_args).to_not eq step.call_args
      end
    end
  end

  describe "#arity" do
    subject { step.arity }

    context "when operation is a proc" do
      let(:operation) { proc { |a, b| a + b } }
      it { is_expected.to eq 2 }
    end

    context "when operation is an object with call method" do
      let(:operation) do
        Class.new do
          def call(a, b, c)
            a + b + c
          end
        end.new
      end

      it { is_expected.to eq 3 }
    end
  end
end
