# Set up for the application and database. DO NOT CHANGE. #############################
require "sinatra"                                                                     #
require "sinatra/reloader" if development?                                            #
require "sequel"                                                                      #
require "logger"                                                                      #
require "twilio-ruby"                                                                 #
require "bcrypt"                                                                      #
require "geocoder"                                                                    #
connection_string = ENV['DATABASE_URL'] || "sqlite://#{Dir.pwd}/development.sqlite3"  #
DB ||= Sequel.connect(connection_string)                                              #
DB.loggers << Logger.new($stdout) unless DB.loggers.size > 0                          #
def view(template); erb template.to_sym; end                                          #
use Rack::Session::Cookie, key: 'rack.session', path: '/', secret: 'secret'           #
before { puts; puts "--------------- NEW REQUEST ---------------"; puts }             #
after { puts; }                                                                       #
#######################################################################################

restaurants_table = DB.from(:restaurants)
reviews_table = DB.from(:reviews)
users_table = DB.from(:users)

# put your API credentials here (found on your Twilio dashboard)
account_sid = ENV['TWILIO_ACCOUNT_SID']
auth_token = ENV['TWILIO_AUTH_TOKEN']
client = Twilio::REST::Client.new(ENV['TWILIO_ACCOUNT_SID'], ENV['TWILIO_AUTH_TOKEN'])
@maps_api_key = ENV['GOOGLE_MAPS_API_KEY']
@twilio_phone = "+12057723880"  



before do
    @current_user = users_table.where(id: session["user_id"]).to_a[0]
end

# homepage and list of restaurants (aka "index")
get "/" do
    puts "params: #{params}"

    @restaurants = restaurants_table.all.to_a
    pp @restaurants

    view "restaurants"
end

# restaurant details (aka "show")
get "/restaurants/:id" do
    puts "params: #{params}"

    # find the restaurant
    @users_table = users_table
    @restaurant = restaurants_table.where(id: params[:id]).to_a[0]
    pp @restaurant

    # show number of reviews
    @reviews = reviews_table.where(restaurant_id: @restaurant[:id]).to_a
    @review_count = reviews_table.count

    # locate input for embedded map
    @map_q = @restaurant[:title].split(" ").join("+")+@restaurant[:location].split(" ").join("+")
    results = Geocoder.search(@restaurant[:location])
    @lat_long = "#{results.first.coordinates[0]},#{results.first.coordinates[1]}"

    view "restaurant"
end

# display the review form (aka "new")
get "/restaurants/:id/reviews/new" do
    puts "params: #{params}"

    @restaurant = restaurants_table.where(id: params[:id]).to_a[0]
    view "new_review"
end

# receive the submitted review form (aka "create")
post "/restaurants/:id/reviews/create" do
    puts "params: #{params}"

    # first find the restaurant that reviewing for
    @restaurant = restaurants_table.where(id: params[:id]).to_a[0]
    # next we want to insert a row in the reviews table with the review form data
    reviews_table.insert(
        restaurant_id: @restaurant[:id],
        user_id: session["user_id"],
        comments: params["comments"]
    )

    redirect "/restaurants/#{@restaurant[:id]}"
end

# display the review form (aka "edit")
get "/reviews/:id/edit" do
    puts "params: #{params}"

    @review= reviews_table.where(id: params["id"]).to_a[0]
    @restaurant = restaurants_table.where(id: @review[:restaurant_id]).to_a[0]
    view "edit_review"
end

# receive the submitted review form (aka "update")
post "/reviews/:id/update" do
    puts "params: #{params}"

    # find the review to update
    @review = reviews_table.where(id: params["id"]).to_a[0]
    # find the reviews restaurant
    @restaurant = restaurants_table.where(id: @review[:restaurant_id]).to_a[0]

    if @current_user && @current_user[:id] == @review[:id]
        reviews_table.where(id: params["id"]).update(
            comments: params["comments"]
        )

        redirect "/restaurants/#{@restaurant[:id]}"
    else
        view "error"
    end
end

# delete the review (aka "destroy")
get "/reviews/:id/destroy" do
    puts "params: #{params}"

    review = reviews_table.where(id: params["id"]).to_a[0]
    @restaurant = restaurants_table.where(id: review[:restaurant_id]).to_a[0]

    reviews_table.where(id: params["id"]).delete

    redirect "/restaurants/#{@restaurant[:id]}"
end

# display the signup form (aka "new")
get "/users/new" do
    view "new_user"
end

# receive the submitted signup form (aka "create")
post "/users/create" do
    puts "params: #{params}"

    # if there's already a user with this email, skip!
    existing_user = users_table.where(email: params["email"]).to_a[0]
    if existing_user
        view "error"
    else
        client.messages.create(
            from: "+12057723880",
            to: "+1#{params["phone"].split("-")}",
            body: "Thanks for creating your Whelp! account!"
        )

        users_table.insert(
            name: params["name"],
            email: params["email"],
            password: BCrypt::Password.create(params["password"])
        )

        redirect "/logins/new"
    end
end

# display the login form (aka "new")
get "/logins/new" do
    view "new_login"
end

# receive the submitted login form (aka "create")
post "/logins/create" do
    puts "params: #{params}"

    # step 1: user with the params["email"] ?
    @user = users_table.where(email: params["email"]).to_a[0]

    if @user
        # step 2: if @user, does the encrypted password match?
        if BCrypt::Password.new(@user[:password]) == params["password"]
            # set encrypted cookie for logged in user
            session["user_id"] = @user[:id]
            redirect "/"
        else
            view "create_login_failed"
        end
    else
        view "create_login_failed"
    end
end

# logout user
get "/logout" do
    # remove encrypted cookie for logged out user
    session["user_id"] = nil
    redirect "/logins/new"
end
