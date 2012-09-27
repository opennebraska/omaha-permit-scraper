#!/usr/bin/env ruby
require './omaha-permits'

COMMON_PERMIT_TYPES = ["12TMP", "BLD", "BOR", "COO", "CRB", "DAN", "ELC", "EXC", "FLD", "LIC", "MEC", "MOV", "PED", "PLB", "SOB", "WRK"]
START_DATE = Date.new(2000,1,1)
END_DATE = Time.now.to_date # today
PREFIX = "output/permitRun-"

def format_permit(permit)
  return "\"permit[:date]\",\"permit[:number]\",\"permit[:type]\",\"permit[:address]\",\"permit[:status]\",\"permit[:pendingAction]\""
end

(START_DATE..END_DATE).each do |day|
  puts "Scraping: " + day.to_s
  File.open(PREFIX + day.to_s + '.csv', 'w') do |f|
    COMMON_PERMIT_TYPES.each do |permit_type|
      ops = OmahaPermitParser.new(day, day, permit_type)
      ops.scrape.each do |permit|
        f.puts format_permit(permit)
      end
    end
  end
end


