load './movie_test.rb'

class MovieData

	attr_accessor :datahash

	def initialize(dir, test = nil)
			# data info file location
			@info = dir + "/u.info"
			# hashmap to store data read from file as well as organized data structures
			@datahash = Hash.new
			# parameter for rescaling popularity index to 0~100 range
			@range
			# cached similar users lists
			@similar_user_cached = Hash.new

		if test.nil? # train full data (u.data) 
			@data = dir + "/u.data"
			# load data from file(s)
			@datahash = {training:tmp = load_data(@data)}
		else # run prediction
			@data = dir + "/" << test.to_s << ".base"
			@test = dir + "/" << test.to_s << ".test"
			# load data from file(s)
			@datahash = {training:tmp1 = load_data(@data), test: tmp2 = load_data(@test)}
		end	

		@range = Math::log(datahash[:training][:review_count].max) - Math::log([datahash[:training][:review_count].min,1].max)
	end

	def load_data(param,test = false)
		# read file into a 2D array
		h = []
		File.open(param) do |f|
			f.each_line do |line|
				h.push(line.split(' ').map{|x| x.to_i})
			end
			f.close()
		end


		# get number of movies and users
		item_count = File.readlines(@info)[1].split[0].to_i
		user_count = File.readlines(@info)[0].split[0].to_i
		
		user_idx = h.transpose[0]
		item_idx = h.transpose[1]
		item_rating = h.transpose[2]

		# number of reviews per movie
		review_count = Array.new(item_count){0}
		# total stars received per movie
		total_stars = Array.new(item_count){0}
		
		# Array of arrays. Each subarry stores users that viewed movies corresponding to idx in the main array 
		movies_viewed_by = Array.new(item_count){[]}
		# Array of movies' averge ratings received
		average_rating = Array.new(item_count){0}
		# Array of arrays. Each subarry stores movie idx viewed by user corresponding to idx in the main array 
		users_reviewed = Array.new(user_count){[]}
		# Array of arrays. Each subarry stores ratings given by user corresponding to idx in the main array 
		users_ratings = Array.new(user_count) {[]}

		# load data into the above arrays
		(0..item_idx.size-1).each {|i|
			review_count[item_idx[i]-1] += 1
			total_stars[item_idx[i]-1] += item_rating[i]
			movies_viewed_by[item_idx[i]-1] << user_idx[i]
			users_reviewed[user_idx[i]-1] << item_idx[i]
			users_ratings[user_idx[i]-1] << item_rating[i]
		}

		# compute average ratings
		average_rating.each_with_index {|avg,idx| 
			if review_count[idx] == 0
				# if not reviewed by any user, assign an average rating of 3
				average_rating[idx] = 3
			else
				average_rating[idx] = (total_stars[idx].to_f/review_count[idx]).round
			end
		}

		# hash to store the above arrays
		data = {movie_reviewers:movies_viewed_by, users_reviewed:users_reviewed, users_ratings:users_ratings, review_count:review_count, total_stars:total_stars, avg_rating:average_rating, full:h}
		return data

	end

	def popularity(movie_id)

		if datahash[:training][:review_count][movie_id-1] == 0
			# A movie that no one reviewed has a popularity index of 0 
			pop = 0
		else
			# Take the log of review count and rescale to 0~100
			pop = (Math::log(datahash[:training][:review_count][movie_id-1])/@range*100).round
		end

		return pop
	end

	def popularity_list(print)

		# Make a hash of all movies' popularity indices
		popularity_hash = Hash.new("n/a")
		(1..datahash[:training][:review_count].size).each {|idx|
		 	popularity_hash[idx] = popularity(idx)
		}

		# Sort the hash
		poplist = popularity_hash.sort_by{|k,v| v}.reverse

		# Print out the list if needed
		if print == true
			print_popularity_list(poplist)
		end
		return poplist
	end

	# Print out the list if needed
	def print_popularity_list(poplist)
		poplist.each {|row| puts "Movie ID: #{row[0]};\t Popularity Index: #{row[1]}"}
	end

	def similarity(user1,user2,obj = :test)

		# Check if current run is for item in training set or test set
		obj = :training unless obj.nil?

		# Find movies that user1 and user2 reviewed in common
		intersect = @datahash[obj][:users_reviewed][user1-1]&movies(user2)

		# If no moives in common then similarity index equals 0
		if intersect.nil?
			sim = 0
		else
			# otherwise determine similarity using Cosine Similarity
			user1_vec = []
			user2_vec = []
			intersect.each do |el|
				user1_vec << @datahash[obj][:users_ratings][user1-1][@datahash[obj][:users_reviewed][user1-1].index(el)]
				user2_vec << @datahash[:training][:users_ratings][user2-1][movies(user2).index(el)]
			end
		end

		return	sim = [intersect.size,20].min/20*dot_product(user1_vec,user2_vec)/Math::sqrt(dot_product(user1_vec,user1_vec))/Math::sqrt(dot_product(user2_vec,user2_vec))
	end

	def dot_product(vector1,vector2)
		return product =  vector1.each_with_index.inject(0) {|sum,(el,idx)|
			sum + el*vector2[idx]
		}
	end


	def most_similar(u,test = nil)

		return @similar_user_cached[u] unless @similar_user_cached[u].nil?

		# puts "\nMost similar users (Modified Pearson Correlation):"
		idx = *(1..@datahash[:training][:users_ratings].size)

		if  test.nil?
			idx = idx-[u]
		end

		most_similar_users = []
		idx.each {|i|
			sim  = similarity(u,i,test)
			if sim>0.5
				most_similar_users << i
			end
		}

		@similar_user_cached[u] = most_similar_users
		return most_similar_users
	end

	def movies(u)
		return @datahash[:training][:users_reviewed][u-1]	
	end

	def rating(u,m)
		m_rating = 0
		m_rating = @datahash[:training][:users_ratings][u-1][movies(u).index(m)] unless movies(u).index(m).nil?
		return m_rating
	end

	def viewers(m)
		return @datahash[:training][:movie_reviewers][m-1]
	end

	def predict(u,m)

		rates_by_su = most_similar(u, true)&viewers(m)

		if rates_by_su.size == 0
			return @datahash[:training][:avg_rating][m-1]
		end

		total_stars = rates_by_su.inject(0) {|sum,el|
				sum + (@datahash[:training][:users_ratings][el-1][movies(el).index(m)])
			}

		return 	predicted = (total_stars.to_f/rates_by_su.size).round
	end

	def run_test(k = nil)

		if k.nil? || k > @datahash[:test][:full].size
			max = @datahash[:test][:full].size
		else
			max = k
		end

		predictions = []
		user_idx = @datahash[:test][:full].transpose[0]
		item_idx = @datahash[:test][:full].transpose[1]

		(0..max-1).each {|i|
			predictions << predict(user_idx[i]-1,item_idx[i])
		}

	 	predictions_obj = MovieTest.new(predictions,@datahash[:test][:full])

	end

end




test = MovieData.new('ml-100k',:u1)
test_obj = test.run_test()

puts "mean err: #{test_obj.mean}"
puts "stddev: #{test_obj.stddev}"
puts "rms: #{test_obj.rms}"
puts "Array size #{test_obj.to_a.size}X#{test_obj.to_a[0].size}"

# 	  Pearson     Cosine
#     0.5 cutoff  0.3 cutoff
# u1: 0.83735	  0.81515
# u2: 0.82475	  0.8096
# u3: 0.8153	  0.79995
# u4: 0.80705	  0.80265
# u5: 0.81275	  0.8126


#   Test size 	  Runtime
# 	10 			  0.7s
#   100 		  0.7s
#   1,000		  3.0s
#   10,000		  29.6s
#   20,000		  58.5s
#


