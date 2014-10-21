module Test
  module A
    extend self
    attr_accessor :one

    def setup
      @one = 1
      @two = 2
    end
  end

  module B
    extend self
    attr_accessor :one

    def setup
      @one = 2
      @two = 1
    end
    setup

    def four( a, b, c )
      puts a, b, c
      puts c
    end

    def method_missing(name, *args)
      puts name
      send( name, args )
    end

    class Stub
      def print
        puts B.one
      end
    end

    class StubA < Stub

    end
  end
end

Test::A.setup
#Test::B.setup

puts Test::A.one
puts Test::B.one
puts Test::B.four(1,2,3)
st = Test::B::StubA.new
puts 8
st.print

module B
  attr_accessor :one
  @one = 3
end

class StubB < Test::B::Stub
  def initialize
    puts B.one
  end
end

stb = StubB.new
stb.print