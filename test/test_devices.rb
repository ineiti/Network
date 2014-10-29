DEBUG_LVL = 5
require 'network'
require 'drb/drb'

DRb.start_service

handler = DRbObject.new_with_uri('druby://localhost:9000')
puts handler.add( {} )

class A
  @ids = 1

  def self.ids
    @ids || -1
  end
end

class B < A
  @ids = 2
end

class C < A

end

puts A.ids
puts B.ids
puts C.ids
