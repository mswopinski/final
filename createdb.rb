# Set up for the application and database. DO NOT CHANGE. #############################
require "sequel"                                                                      #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB = Sequel.connect(connection_string)                                                #
#######################################################################################

# Database schema - this should reflect your domain model
DB.create_table! :restaurants do
  primary_key :id
  String :title
  String :location
end
DB.create_table! :reviews do
  primary_key :id
  foreign_key :restaurant_id
  foreign_key :user_id
  String :comments, text: true
end
DB.create_table! :users do
  primary_key :id
  String :name
  String :email
  String :password
end

DB.create_table! :admins do
  primary_key :id
  String :name
  String :phone
end

# Insert initial (seed) data
restaurants_table = DB.from(:restaurants)

restaurants_table.insert(title: "Pequod's Pizza (Chicago)", 
                    location: "2207 N Clybourn Ave, Chicago, IL 60614")

restaurants_table.insert(title: "Lou Malnati's Pizzeria (Evanston)", 
                    location: "1850 Sherman Ave, Evanston, IL 60201")

admins_table = DB.from(:admins)

admins_table.insert(name: "Mick Wopinski", 
                    phone: "+17738526425")

puts "Successfully initialized DB!"