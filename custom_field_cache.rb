#!/usr/bin/env ruby
# tablecounts.rb - Show all the tables from a database, including the count(*) from each table
require 'rubygems'
require 'mysql'

database=ARGV[0] || 'leadgen_development'

def max(a,b)
  a>b ? a : b
end

begin
  # connect to the MySQL server
  dbh = Mysql.real_connect("localhost", "root", "", database)
  
  res = dbh.query("SELECT * FROM custom_fields")
  row_count = 0
  while row = res.fetch_row do
    puts "Passing #{row_count}..." if row_count%1000==0
    row_count += 1  # stupid, but you get the idea
  end
  res.free
  puts "All done. Counted #{row_count} rows."
rescue Mysql::Error => e
  puts "Error code: #{e.errno}"
  puts "Error message: #{e.error}"
  puts "Error SQLSTATE: #{e.sqlstate}" if e.respond_to?("sqlstate")
ensure
  # disconnect from server
  dbh.close if dbh
end

