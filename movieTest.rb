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
