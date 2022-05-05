#!/usr/bin/env ruby

require 'nokogiri'
require 'faraday'
require 'attr-utils'
require 'pry-byebug'

NICHIGIN_URL = "https://www.boj.or.jp/statistics/dl/loan/prime/prime.htm/"

class PrimeRate
  include AttrUtils
  attr_accessor :date, :mode, :max, :min, :long

  def to_csv
    return "#{self.date},#{self.mode},#{self.max},#{self.min},#{self.long}"
  end
end

def parse_date(date)
  nbsp = 160.chr("UTF-8")
  date.gsub(nbsp, '') =~ /（(.*)）年(.*)月(.*)日/
  year = $1.to_i
  month = $2.to_i
  day = $3.to_i

  return Date.new(year, month, day)
end

def rate_value(rate_node, prev_value)
  # [1] pry(main)> rates[0]
  # => #(Element:0x6cc {
  #   name = "td",
  #   attributes = [ #(Attr:0x6e0 { name = "class", value = "txt-right" })],
  #   children = [ #(Text "↓")]
  #   })

  value = rate_node.children.first.text

  if value == "↓"
    value = prev_value
  else
    # "不定"のような値があるので、その場合は過去の値を利用
    begin
      Float(value)
    rescue ArgumentError => e
      value = prev_value
    end
  end

  return value
end

def retrieve_prime_rates(rate_nodes, prev_prime_rate)
  p = PrimeRate.new

  # 0th: 最頻値(mode)
  # 1th: 最高値(max)
  # 2nd: 最低値(min)
  # 3rd: 長期プライムレート(long)
  p.mode = rate_value(rate_nodes[0], prev_prime_rate&.mode)
  p.max = rate_value(rate_nodes[1], prev_prime_rate&.max)
  p.min = rate_value(rate_nodes[2], prev_prime_rate&.min)
  p.long = rate_value(rate_nodes[3], prev_prime_rate&.long)

  return p
end

def display_as_csv(rates)
  puts "実施日,最頻値,最高値,最低値,長期プレイムレート"
  rates.each do |rate|
    puts rate.to_csv
  end
end

def main
  r = Faraday.get(NICHIGIN_URL)
  html = Nokogiri::HTML(r.body)
  rows = html.xpath('//div[@class="tbl-box"]/table/tbody/tr')
  prime_rates = []

  rows.each_with_index do |tr, i|
    rate_nodes = tr.xpath('td')
    prev_prime_rate = i == 0 ? nil : prime_rates[i-1]
    prime_rate = retrieve_prime_rates(rate_nodes, prev_prime_rate)

    date_str = tr.xpath('th').text
    prime_rate.date = parse_date(date_str)

    prime_rates << prime_rate
  end

  display_as_csv(prime_rates)
end

main
