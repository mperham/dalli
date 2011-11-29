# encoding: utf-8
require 'helper'
require 'memcached_mock'

describe 'Encoding' do

  context 'using a live server' do
    should 'support i18n content' do
      memcached do |dc|
        key = 'foo'
        nonascii_key = utf8 = 'ƒ©åÍÎ'

        assert dc.set(key, utf8)
        assert_equal utf8, dc.get(key)

        assert dc.set(nonascii_key, utf8)
        assert_equal utf8, dc.get(nonascii_key)
      end
    end

    should 'support content expiry' do
      memcached do |dc|
        key = 'foo'
        assert dc.set(key, 'bar', 1)
        assert_equal 'bar', dc.get(key)
        sleep 2
        assert_equal nil, dc.get(key)
      end
    end

    should 'support non-ASCII keys' do
      memcached do |dc|
        key = 'fooƒ'
        assert dc.set(key, 'bar')
        assert_equal 'bar', dc.get(key)
      end
    end

  end
end
