# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VesFormModel do
  let(:test_class) do
    Class.new do
      include VesFormModel
    end
  end

  let(:instance) { test_class.new }

  describe 'default implementations' do
    describe '#form_1010d?' do
      it 'returns false by default' do
        expect(instance.form_1010d?).to be(false)
      end
    end

    describe '#form_1010dx?' do
      it 'returns false by default' do
        expect(instance.form_1010dx?).to be(false)
      end
    end

    describe '#form_7959c?' do
      it 'returns false by default' do
        expect(instance.form_7959c?).to be(false)
      end
    end
  end

  describe 'override behavior' do
    let(:overriding_class) do
      Class.new do
        include VesFormModel

        def form_1010d?
          true
        end
      end
    end

    it 'allows including classes to override methods' do
      expect(overriding_class.new.form_1010d?).to be(true)
      expect(overriding_class.new.form_7959c?).to be(false)
    end
  end
end
