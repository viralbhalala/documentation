require 'nokogiri'
require 'singleton'
require 'socket'
require 'digest/md5'


class BranchUtils
  include Singleton
  attr_accessor :jsx

  def initialize
    @_react = {}

    sock = Dir.mktmpdir + '/' + (0...10).map { ('a'..'z').to_a[rand(26)] }.join

    @pid = fork do
      exec 'node', File.dirname(__FILE__) + '/_render.js', sock
    end
    sleep 1

    @s1 = UNIXSocket.new(sock)

  end


  def bundle(content)
    @s1.send JSON.generate({ :type => "bundle", :data => content }), 0

    length = Integer(@s1.recv(10).sub(/^0+/, ''))
    out = ""
    while out.length < length do
      out += @s1.recv([length - out.length, 10000].max)
    end

    JSON.parse('[' + out + ']')[0]
  end

  def react(content)
    if @_react[content] then
      @_react[content]
    else
     @s1.send JSON.generate({ :type => "react", :data => _to_jsx(Nokogiri::XML(content).children[0]) }), 0
      @_react[content] = @s1.recv(1000 * 1000 * 1000)
    end
  end

  def _to_jsx(content)
    attr_translate = { "for" => "htmlFor", "class" => "className" }
  
    if content.text? then
      "{" + ("" + content).to_json + "}"
    elsif content.element?
      res = "<" + content.name + (content.attributes.map { |_,attr| ' ' + (attr_translate[attr.name] or attr.name) + '=' + attr.value.to_json }.join '')
      if content.children.count then
        res + '>' + (content.children.map { |child| _to_jsx(child) }.join '') + '</' + content.name + '>'
      else
        res + ' />'
      end
    else
      ""
    end
  end
end