class User < ActiveRecord::Base
	has_many :microposts, dependent: :destroy
	has_many :active_relationships, class_name: "Relationship", 
				foreign_key: "follower_id", 
				dependent: :destroy
	has_many :passive_relationships, class_name: "Relationship",
							foreign_key: "followed_id",
							dependent: :destroy
	has_many :following, through: :active_relationships, source: :followed
	has_many :followers, through: :passive_relationships, source: :follower
	attr_accessor :remember_token, :activation_token, :reset_token
	before_save :downcase_email
	before_create :create_activation_digest
	validates :name, presence: true, length: { maximum: 50 }
	VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
	validates :email, presence: true, length: { maximum: 255 }, 
				format: { with: VALID_EMAIL_REGEX },
				uniqueness: { case_sensitive: false }

	has_secure_password
	validates :password, length: { minimum: 6 }, allow_blank: true 	

	# Returns the hash digest of the given string.
	def User.digest(string)
		cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
													  BCrypt::Engine.cost
		BCrypt::Password.create(string, cost: cost)
	end		

	# Returns a random token.
	def User.new_token
		SecureRandom.urlsafe_base64
	end

	# Remembers a user in the database for use in persistent sessions.
	def remember
		self.remember_token = User.new_token
		update_attribute(:remember_digest, User.digest(remember_token))
	end

	#Returns true if the given token matches the digest.
	def authenticated?(attribute, token)
		digest = send("#{attribute}_digest")
		return false if digest.nil?
		BCrypt::Password.new(digest).is_password?(token)
	end

	#Forgets a user
	def forget
		update_attribute(:remember_digest, nil)
	end

	#def feed
	#	Micropost.where("user_id = ?", id)
	#end
	
	# Unfollows a user.
	def unfollow(other_user)
		active_relationships.find_by(followed_id: other_user.id).destroy
	end

	# Returns true if the current user is following the other user.
	def following?(other_user)
		following.include?(other_user)
	end

	# Activates an account.
	def activate
		update_attribute(:activated, true)
		update_attribute(:activated_at, Time.zone.now)
	end

	# Sends activation email.
	def send_activation_email
		UserMailer.account_activation(self).deliver_now
	end

	# Sets the password reset attributes.
	def create_reset_digest
		self.reset_token = User.new_token
		update_attribute(:reset_digest, User.digest(reset_token))
		update_attribute(:reset_sent_at, Time.zone.now)
	end

	# Sends password reset email.
	def send_password_reset_email
		UserMailer.password_reset(self).deliver_now
	end

	def password_reset_expired?
		reset_sent_at < 2.hours.ago
	end

	# Returns a user's status feed.
	def feed
		following_ids = "SELECT followed_id FROM relationships
									WHERE follower_id = :user_id"
		Micropost.where("user_id IN (#{following_ids})
									OR user_id = :user_id", user_id: id)
	end

	# Follows a user.
	def follow(other_user)
		active_relationships.create(followed_id: other_user.id)
	end
	
	private

		#Converts email to all lower-case
		def downcase_email
			self.email = email.downcase
		end

		#Creates and assigns the activation token and digest
		def create_activation_digest
			self.activation_token = User.new_token
			self.activation_digest = User.digest(activation_token)
		end
end