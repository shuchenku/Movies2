# movies-2

CODECLIMATE REPORTS:

MovieData class: https://codeclimate.com/repos/54cac94ae30ba00498001947/MovieData
MovieTest class: It was rated A but now CodeClimate fails to recognized that file.

My interpretation of the Codeclimate Grading:

    Playing with CodeClimate gives me the sense that it emphisizes more on class simplictity rather than algorithm complextity.
My similarity function, which adopts a modified Cosine Similarity as metric, requires extra data structures and more lines of
mathematical operations to be O(n).
    CodeClimate to did not like that and marked it as a high complexity function; the same is with
my load_data() function where extra data structures were created to enable faster access to movies/users/rating. The way I designed
the MovieData class is mainly focused on efficiency; if it was designed differently I imagine many of the methods will be O(n squared)
complexity but CodeClimate might give me a better score. After considering the tradeoffs I decided to stick with what I have
and be happy with a D (also ~ 1 min runtime).


 MEAN ERROR
 	 Pearson     Cosine
     0.5 cutoff  0.5 cutoff
 u1: 0.83735	  0.7959
 u2: 0.82475	  0.79305
 u3: 0.8153	  	  0.7912
 u4: 0.80705	  0.7916
 u5: 0.81275	  0.7966

 RUNTIME
 Test size(u1) Runtime
 10 			  1.0s
 100 			  1.0s
 1,000		  	  3.1s
 10,000		  	  27.4s
 20,000		  	  54.8s
 20,000(u3,4,5)   ~70s


INDEX DEFINATION:

popularity index = 1/log(# of reviews)

similarity index = min(intersect(# of user1 reviewed movies, # of user2 reviewed movies), 8)/8 * cosine similarity
Cutoff similarity index value for being "most similar": 0.5

	* min # of movies required to not get penalized is set to be 8 b/c it gives the best prediction results.
	* Cosine similarity improved prediction accuracy compared to Pearson correlation, therefore I cheaged the algorithm in Movies-2

Prediction of user u on movies m is based on average rating of u's similar users's ratings on m.
