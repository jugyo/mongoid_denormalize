class Comment
  include Mongoid::Document
  include Mongoid::Denormalize
  
  field :body
  
  embedded_in :post, :inverse_of => :comments
  referenced_in :user
  
  denormalize :name, :from => :user
  denormalize :email, :from => :user
  denormalize :created_at, :type => Time, :from => :post
end