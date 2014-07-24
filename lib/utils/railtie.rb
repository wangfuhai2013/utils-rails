require 'utils/view_helper'
module Utils
  class Railtie < Rails::Railtie
    initializer "utils.view_helper" do
      ActionView::Base.send :include, ViewHelper
    end
  end
end