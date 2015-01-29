load './movie_test.rb'

class MovieData

	attr_accessor :datahash

	def initialize(dir, test = nil)
			# data info file location
			info_file = File.readlines(File.join(dir,"u.info"))
			# get number of movies and users
			@item_count = info_file[1].split[0].to_i
			@user_count = info_file[0].split[0].to_i
			# cached similar users lists
			@similar_user_cached = Hash.new

		if test.nil? # train full data (u.data) 
			@data = File.join(dir,"u.data")
		else # run prediction
			@data = File.join(dir,test.to_s << ".base")
			@test = File.join(dir,test.to_s << ".test")
			# hashmap to store data read from file as well as organized data structures
			@datahash = {test:load_data(@test)}
		end	

		# load data from file(s)
		@datahash[:training] = load_data(@data)
		@datahash[:training][:avg_ratings] = avg_ratings()
		# parameter for rescaling popularity index to 0~100 range
		review_counts = datahash[:training][:review_count]
		@range = Math::log(review_counts.max) - Math::log(review_counts.min,1].max)
	end

	# this will read in the data from the original ml-100k files and stores them in whichever way it needs to be stored
	def load_data(param,test = false)
		# read file into a 2D array
		h = []

		# number of reviews per movie
		review_count = Array.new(@item_count){0}
		# total stars received per movie
		total_stars = Array.new(@item_count){0}		
		# Array of arrays. Each subarry stores users that viewed movies corresponding to idx in the main array 
		movies_viewed_by = Array.new(@item_count){[]}
		# Array of movies' averge ratings received
		average_rating = Array.new(@item_count){3}
		# Array of arrays. Each subarry stores movie idx viewed by user corresponding to idx in the main array 
		users_reviewed = Array.new(@user_count){[]}
		# Array of arrays. Each subarry stores ratings given by user corresponding to idx in the main array 
		users_ratings = Array.new(@user_count) {[]}

		# Reads input file and loads data into the above structures
		File.open(param) do |f|
			f.each_line do |line|
				cur_line = line.split(' ').map{|x| x.to_i}
				review_count[cur_line[1]-1] += 1
				total_stars[cur_line[1]-1] += cur_line[2]
				movies_viewed_by[cur_line[1]-1] << cur_line[0]
				users_reviewed[cur_line[0]-1] << cur_line[1]
				users_ratings[cur_line[0]-1] << cur_line[2]
				h.push(cur_line)
			end
			f.close()
		end

		# hash to store the above arrays
		data = {movie_reviewers:movies_viewed_by, users_reviewed:users_reviewed, users_ratings:users_ratings, review_count:review_count, total_stars:total_stars, full:h}
		return data

	end

	def avg_ratings()
			# Array of movies' averge ratings received
			average_rating = Array.new(@item_count){3}
			average_rating.each_with_index {|avg,idx| 
				stars = @datahash[:training][:total_stars][idx]
				reviews = @datahash[:training][:review_count][idx]
				average_rating[idx] = (stars.to_f/reviews).round unless reviews == 0
		}
		return average_rating
	end

	# this will return a number that indicates the popularity (higher numbers are more popular). You should be prepared to explain the reasoning behind your definition of popularity
	def popularity(movie_id)

		cur_movie = datahash[:training][:review_count][movie_id-1]
		if cur_movie == 0
			# A movie that no one reviewed has a popularity index of 0 
			return 0
		end

		# Take the log of review count and rescale to 0~100
		return pop = (Math::log(cur_movie)/@range*100).round
	end

	# this will generate a list of all movie_id’s ordered by decreasing popularity
	def popularity_list(print = nil)

		# Make a hash of all movies' popularity indices
		popularity_hash = Hash.new("n/a")
		(1..datahash[:training][:review_count].size).each {|idx|
		 	popularity_hash[idx] = popularity(idx)
		}

		# Sort the hash
		poplist = popularity_hash.sort_by{|k,v| v}.reverse

		# Print out the list if needed
		return poplist
	end

	# Print out the list if needed
	def print_popularity_list(poplist)
		poplist.each {|row| puts "Movie ID: #{row[0]};\t Popularity Index: #{row[1]}"}
	end

	# this will generate a number which indicates the similarity in movie preference between user1 and user2 (where higher numbers indicate greater similarity)
	def similarity(user1,user2,obj = :test)

		# Check if current run is for item in training set or test set
		obj = :training unless obj.nil?

		# Find movies that user1 and user2 reviewed in common
		intersect = @datahash[obj][:users_reviewed][user1-1]&movies(user2)

		# If no moives in common then similarity index equals 0
		if intersect.nil?
			return 0
		end

		# otherwise determine similarity using Cosine Similarity
		user1_vec = []
		user2_vec = []
		intersect.each do |el|
			movie_idx = @datahash[obj][:users_reviewed][user1-1].index(el)
			user1_vec << @datahash[obj][:users_ratings][user1-1][movie_idx]
			user2_vec << rating(user2,el)
		end

		penalty = [intersect.size,20].min/20
		numerator = dot_product(user1_vec,user2_vec)
		denominator1 = Math::sqrt(dot_product(user1_vec,user1_vec))
		denominator2 = Math::sqrt(dot_product(user2_vec,user2_vec))
		return	sim = penalty*numerator/denominator1/denominator2
	
	end

	# computes dot product of 2 vectors
	def dot_product(vector1,vector2)
		return product =  vector1.each_with_index.inject(0) {|sum,(el,idx)|
			sum + el*vector2[idx]
		}
	end

	# this return a list of users whose tastes are most similar to the tastes of user u
	def most_similar(u,test = nil)
		# If the object user's similar users have already been computed, read from hash
		return @similar_user_cached[u] unless @similar_user_cached[u].nil?

		# Users that has cosine similiarity >0.5 with the object user are added to the similar users list
		most_similar_users = []
		(1..@datahash[:training][:users_ratings].size).each {|i|
			sim  = similarity(u,i,test)
			most_similar_users << i unless sim<0.5 || sim == 1
		}

		# Cache the similar users list
		@similar_user_cached[u] = most_similar_users
		return most_similar_users
	end

	# returns the array of movies that user u has watched
	def movies(u)
		return @datahash[:training][:users_reviewed][u-1]	
	end

	# returns the rating that user u gave movie m in the training set, and 0 if user u did not rate movie m
	def rating(u,m)
		m_rating = 0
		m_rating = @datahash[:training][:users_ratings][u-1][movies(u).index(m)] unless movies(u).index(m).nil?
		return m_rating
	end

	# returns the array of users that have seen movie m
	def viewers(m)
		return @datahash[:training][:movie_reviewers][m-1]
	end

	# returns a floating point number between 1.0 and 5.0 as an estimate of what user u would rate movie m
	def predict(u,m)

		# Users that are similar to u && also reviewed movie m
		rates_by_su = most_similar(u, true)&viewers(m)

		# If no such users then assume u will give it an average rating
		return @datahash[:training][:avg_ratings][m-1] unless rates_by_su.size > 0

		# Otherwise predict that u will give movie m a rating equal to what his/her similar user gave
		total_stars = rates_by_su.inject(0) {|sum,el|
				sum + rating(el,m)
			}

		return 	predicted = (total_stars.to_f/rates_by_su.size).round
	end

	# runs the z.predict method on the first k ratings in the test set and returns a MovieTest object containing the results.
	# The parameter k is optional and if omitted, all of the tests will be run.
	def run_test(k = nil)
		temp = @datahash[:test][:full]
		# Check if test set size has been specified
		if k.nil? || k > temp.size
			max = temp.size
		else
			max = k
		end

		# Make predictions for every user/movie pair and store results in an array
		predictions = []
		user_idx = temp.transpose[0]
		item_idx = temp.transpose[1]

		user_idx[(0..max)].each_with_index {|uidx,idx|
			predictions << predict(uidx-1,item_idx[idx])
		}
	 	predictions_obj = MovieTest.new(predictions,temp)

	end

end




test = MovieData.new('ml-100k',:u4)
test_obj = test.run_test()

puts "mean err: #{test_obj.mean}"
puts "stddev: #{test_obj.stddev}"
puts "rms: #{test_obj.rms}"
puts "Array size #{test_obj.to_a.size}X#{test_obj.to_a[0].size}"

# 	  Pearson     Cosine
#     0.5 cutoff  0.5 cutoff
# u1: 0.83735	  0.81215
# u2: 0.82475	  0.8134
# u3: 0.8153	  0.81165
# u4: 0.80705	  0.8145
# u5: 0.81275	  0.82285

#   Test size(u1) Runtime
# 	10 			  1.1s
#   100 		  1.1s
#   1,000		  3.0s
#   10,000		  27.2s
#   20,000		  67.6s
#   20,000(u3,4,5)~150s




