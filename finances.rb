require 'sinatra'
require "sinatra/reloader" if development?
require 'sequel'
require 'haml'
require 'securerandom'
require 'rack'


set :bind, '0.0.0.0'

def is_number? string
	true if Integer(string) rescue false
end

DB = Sequel.sqlite('test.db')
Sequel::Model.plugin :subclasses
require_relative 'models'

Sequel::Model.freeze_descendents
DB.freeze


set :haml, :format => :html5

get "/" do
	haml :index
end

get "/record" do
	@categories = DB[:categories].
		left_join(:category_budgets, category_id: :cat_id).
		all
	@chosen_category = nil
	haml :record_expense
end

get "/record/:category" do
	cat_id = Integer(params[:category])
	@chosen_category = DB[:categories].
		left_join(:category_budgets, category_id: :cat_id).
		where(cat_id: cat_id).
		first
	puts @chosen_category
	haml :record_expense
end

post "/record" do
	amount = BigDecimal(params[:amount])
	cat_id = Integer(params[:chosen_category])
	notes = params[:notes]

	DB.transaction do
		tr_id = DB[:transacions].insert(amount: amount)
		DB[:categories_transactions].insert(category_id: cat_id, transaction_id: tr_id)
		unless notes.nil? then
			DB[:notes].insert(transaction_id: tr_id, note: notes)
		end
	end
end

put "/expense/:id" do

end

get "/category/create" do
	@categories = DB[:categories].
		left_join(:category_budgets, category_id: :cat_id).
		all
	haml :create_category
end

get "/category/edit/:id" do
	id = Integer(params[:id])
	@category = DB[:categories].
		left_join(:category_budgets, category_id: :cat_id).
		where(:cat_id => id).
		first
	haml :edit_category
end

post "/category/edit/:id" do
	id = Integer(params[:id])
	name = params[:category_name]
	budget = BigDecimal(params[:category_budget])

	DB.transaction do
		DB[:categories].where({cat_id: id}).update(name: name)
		if budget > 0 then
			DB[:category_budgets].insert_conflict(:replace).
				insert(budget: budget, category_id: id)
		end
	end

	redirect "/category/edit/#{id}"
end

post "/category" do
	name = params[:category_name]
	DB[:categories].insert(name: name)
	redirect "/category/create"
end


get "/images/:id" do
	id = Integer(params[:id])
	path = DB[:images].where({image_id: id}).first[:path]
	send_file path
end

get "/upload_image" do
	haml :upload_image
end

post "/upload_image" do
	ext = File.extname(params[:file][:filename])
	filename = SecureRandom.uuid() + ext 
	file = params[:file][:tempfile]

	# Copy file from tmpdir
	File.open("./public/images/#{filename}", "wb") do |f|
		f.write(file.read)
	end

	id = DB[:images].insert(path: "./public/images/#{filename}")
	redirect "/images/#{id}"
end