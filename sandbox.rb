@restaurant = Hash.new
@restaurant[:location] = "2207 N Clybourn Ave, Chicago, IL 60614"

q = @restaurant[:location].split(" ").join("+")

print q