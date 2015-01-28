class MovieTest

	def initialize(predictions,test_data)
		@u = test_data.transpose[0]
		@m = test_data.transpose[1]
		@r = test_data.transpose[2]
		@p = predictions
		@test_data = test_data

	end

	# returns the average predication error
	def mean()
		diff = @p.each_with_index.inject(0) {|sum,(el,idx)|
			sum + (@r[idx] - el).abs
		}
		return mean_err = diff.to_f/@p.size
	end

	# returns the standard deviation of the error
	def stddev
		avgerr = mean()
		sqrd = @p.each_with_index.inject(0) {|sum,(el,idx)|
			sum + ((@r[idx] - el).abs-avgerr)**2
		}
		return stdderr = Math::sqrt(sqrd.to_f/@p.size)
	end

	# returns the root mean square error of the prediction
	def rms
		sqrd = @p.each_with_index.inject(0) {|sum,(el,idx)|
			sum + (@r[idx] - el)**2
		}
		return rms = Math::sqrt(sqrd.to_f/@p.size)		
	end

	# returns an array of the predictions in the form [u,m,r,p]
	def to_a
		return (@test_data[(0..@p.size-1)].transpose[(0..2)] << @p).transpose
	end

end
