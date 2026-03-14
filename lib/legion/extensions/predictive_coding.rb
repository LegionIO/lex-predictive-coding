# frozen_string_literal: true

require 'securerandom'
require 'legion/extensions/predictive_coding/version'
require 'legion/extensions/predictive_coding/helpers/constants'
require 'legion/extensions/predictive_coding/helpers/prediction_error'
require 'legion/extensions/predictive_coding/helpers/generative_model'
require 'legion/extensions/predictive_coding/runners/predictive_coding'

module Legion
  module Extensions
    module PredictiveCoding
      extend Legion::Extensions::Core if Legion::Extensions.const_defined? :Core
    end
  end
end
