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
		File.readlines(param).each do |line|
			h.push(line.split(' ').map{|x| x.to_i})
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
		
		movies_viewed_by = Array.new(item_count){[]}
		average_rating = Array.new(item_count){0}
		users_reviewed = Array.new(user_count){[]}
		users_ratings = Array.new(user_count) {[]}

		(0..item_idx.size-1).each {|i|
			review_count[item_idx[i]-1] += 1
			total_stars[item_idx[i]-1] += item_rating[i]
			movies_viewed_by[item_idx[i]-1] << user_idx[i]
			users_reviewed[user_idx[i]-1] << item_idx[i]
			users_ratings[user_idx[i]-1] << item_rating[i]
		}

		average_rating.each_with_index {|avg,idx| 
			if review_count[idx] == 0
				average_rating[idx] = 3
			else
				average_rating[idx] = (total_stars[idx].to_f/review_count[idx]).round
			end
		}

		data = {movie_reviewers:movies_viewed_by, users_reviewed:users_reviewed, users_ratings:users_ratings, review_count:review_count, total_stars:total_stars, avg_rating:average_rating, full:h}
		return data

	end

	def popularity(movie_id)

		if datahash[:training][:review_count][movie_id-1] == 0
			pop = 0
		else
			pop = (Math::log(datahash[:training][:review_count][movie_id-1])/@range*100).round
		end

		return pop
	end

	def popularity_list(print)
		popularity_hash = Hash.new("n/a")
		(1..datahash[:training][:review_count].size).each {|idx|
		 	popularity_hash[idx] = popularity(idx)
		}

		poplist = popularity_hash.sort_by{|k,v| v}.reverse

		if print == true
			puts "\nMost popular movies (descending):"
			poplist.each {|row| puts "Movie ID: #{row[0]};\t Popularity Index: #{row[1]}"}
		end
		return poplist
	end

	def similarity(user1,user2,obj = :test)

		obj = :training unless obj.nil?
			
		end

		intersect = @datahash[obj][:users_reviewed][user1-1]&movies(user2)
		if intersect.size == 0
			sim = 0
		else
			temp = intersect.size-1
			numerator = (0..temp).inject(0) {|sum,el| 
				sum + (@datahash[obj][:users_ratings][user1-1][@datahash[obj][:users_reviewed][user1-1].index(intersect[el])])*(@datahash[:training][:users_ratings][user2-1][movies(user2).index(intersect[el])])
			} 

			term1 = (0..temp).inject(0) {|sum,el| 
				sum + (@datahash[obj][:users_ratings][user1-1][@datahash[obj][:users_reviewed][user1-1].index(intersect[el])])**2
			}

			term2 = (0..temp).inject(0) {|sum,el|
				sum + (@datahash[:training][:users_ratings][user2-1][movies(user2).index(intersect[el])])**2
			}

			sim = [temp+1,20].min/20*numerator/Math::sqrt(term1)/Math::sqrt(term2)
		end

		return sim
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
		most_similar_users = most_similar(u, true)

		m_reviewers = viewers(m)
		rates_by_su = most_similar_users&m_reviewers

		if rates_by_su.size == 0
			return @datahash[:training][:avg_rating][m-1]
		end

		total_stars = rates_by_su.inject(0) {|sum,el|
				sum + (@datahash[:training][:users_ratings][el-1][movies(el).index(m)])
			}

		predicted = (total_stars.to_f/rates_by_su.size).round

		return predicted
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
		users_ratings = @datahash[:test][:full].transpose[2]

		(0..max-1).each {|i|
			predictions << predict(user_idx[i]-1,item_idx[i])
		}

	 	predictions_obj = MovieTest.new(predictions,@datahash[:test][:full])

	end

end


class MovieTest

	def initialize(predictions,test_data)
		@u = test_data.transpose[0]
		@m = test_data.transpose[1]
		@r = test_data.transpose[2]
		@p = predictions
		@test_data = test_data

	end

	def mean()
		diff = (0..@p.size-1).inject(0) {|sum,el|
			sum + (@r[el] - @p[el]).abs
		}
		return mean_err = diff.to_f/@p.size
	end

	def stddev
		avgerr = mean()
		sqrd = (0..@p.size-1).inject(0) {|sum,el|
			sum + ((@r[el] - @p[el]).abs-avgerr)**2
		}
		return stdderr = Math::sqrt(sqrd.to_f/@p.size)
	end

	def rms
		sqrd = (0..@p.size-1).inject(0) {|sum,el|
			sum + (@r[el] - @p[el])**2
		}
		return rms = Math::sqrt(sqrd.to_f/@p.size)		
	end

	def to_a
		return (@test_data[(0..@p.size-1)].transpose[(0..2)] << @p).transpose
	end

end


# test = MovieData.new('ml-100k',:u1)
# test_obj = test.run_test()

# puts "mean err: #{test_obj.mean}"
# puts "stddev: #{test_obj.stddev}"
# puts "rms: #{test_obj.rms}"
# puts "Array size #{test_obj.to_a.size}X#{test_obj.to_a[0].size}"

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


