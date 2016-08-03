require 'chewy/translation/query'
require 'chewy/translation/index'
require 'chewy/translation/version'

module Chewy
  module Translation
    Chewy::Query.send(:include, Chewy::Translation::Query)
    Chewy::Index.send(:include, Chewy::Translation::Index)
    Chewy::Type.send(:include, Chewy::Translation::Index)
  end
end
