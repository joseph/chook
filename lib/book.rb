module Chook

  class Book

    # An array of hashes of the form:
    #   [
    #     uri => string-contents-of-component,
    #     ...
    #   ]
    attr_accessor :components

    # A hash hierarchy of the form:
    #   [
    #     {
    #       :title => ...,
    #       :src => ...,
    #       :children => [
    #       ]
    #     }
    #   ]
    #
    attr_accessor :contents

    # A simple hash of the form:
    #   name => value
    attr_accessor :metadata


    def initialize
      @components = []
      @contents = []
      @metadata = {}
    end

  end

end
