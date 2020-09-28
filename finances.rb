require 'sinatra'
require "sinatra/reloader"
require 'sequel'
require 'haml'
require 'securerandom'
require 'rack'


set :bind, '0.0.0.0' if development?
set :haml, :format => :html5

def is_number? string
  true if Integer(string) rescue false
end

DB = Sequel.sqlite('test.db')
Sequel::Model.plugin :subclasses

Sequel::Model.freeze_descendents
DB.freeze


def get_budgets
  category_map = Hash.new 
  DB[:categories].all().each do |cat|
    category_map[cat[:cat_id]] = cat[:name]
  end

  transactions = DB[:transactions].
    left_join(:categories_transactions, transaction_id: :transaction_id).
    left_join(:categories, cat_id: :category_id).
    left_join(:transaction_notes, transaction_id: Sequel[:transactions][:transaction_id]).
    order(:tx_time).
    all()

  sums_by_cat = Hash.new(BigDecimal(0))
  transactions.group_by{|tx| tx[:cat_id]}.each do |k, txgrp|
    txgrp.each do |tx|
      cat_id = tx[:category_id]
      sums_by_cat[cat_id] += tx[:amount]
    end
  end

  budgets = Hash.new
  DB[:category_budgets].order(Sequel.desc(:budget)).all().each do |budget|
    cat = budget[:category_id]
    budgets[budget[:category_id]] = {
      :name => category_map[cat],
      :expenses => sums_by_cat[cat],
      :budget => budget[:budget],
      :category => cat
    }
  end

  {
    :budgets => budgets,
    :transactions => transactions
  }

end


get "/" do
  haml :index
end

get "/record" do
  money_info = get_budgets
  @categories = money_info[:budgets]
  @chosen_category = nil
  haml :record_expense
end

get "/record/:category" do
  cat_id = Integer(params[:category])
  money_info = get_budgets
  @chosen_category = money_info[:budgets][cat_id]
  haml :record_expense
end

post "/record" do
  amount = BigDecimal(params[:amount])
  cat_id = Integer(params[:chosen_category])
  notes = params[:notes]

  DB.transaction do
    tr_id = DB[:transactions].insert(amount: amount)
    DB[:categories_transactions].insert(category_id: cat_id, transaction_id: tr_id)
    unless notes.nil? then
      DB[:transaction_notes].insert(transaction_id: tr_id, note: notes)
    end
  end
  redirect "/"
end

get "/expenses" do

  money_info = get_budgets

  @budgets = money_info[:budgets]
  @transactions = money_info[:transactions]

  haml :expense_dashboard

end

get "/expense/:id/cat-change" do
  tx_id_col = Sequel[:transactions][:transaction_id]
  @tx = DB[:transactions].
    left_join(:categories_transactions, transaction_id: :transaction_id).
    left_join(:categories, cat_id: :category_id).
    left_join(:transaction_notes, transaction_id: tx_id_col).
    where({tx_id_col => Integer(params[:id])}).
    first
  money_info = get_budgets
  @categories = money_info[:budgets]

  @chosen_category = nil
  haml :edit_expense
end

get "/expense/:id/cat-set-to/:cat_id" do
  tx_id_col = Sequel[:transactions][:transaction_id]
  @tx = DB[:transactions].
    left_join(:categories_transactions, transaction_id: :transaction_id).
    left_join(:categories, cat_id: :category_id).
    left_join(:transaction_notes, transaction_id: tx_id_col).
    where({tx_id_col => Integer(params[:id])}).
    first


  @chosen_category = get_budgets[:budgets][Integer(params[:cat_id])]
  haml :edit_expense
end

get "/expense/:id" do
  tx_id_col = Sequel[:transactions][:transaction_id]
  @tx = DB[:transactions].
    left_join(:categories_transactions, transaction_id: :transaction_id).
    left_join(:categories, cat_id: :category_id).
    left_join(:transaction_notes, transaction_id: tx_id_col).
    where({tx_id_col => Integer(params[:id])}).
    first

  @chosen_category = get_budgets[:budgets][@tx[:cat_id]]
  haml :edit_expense
end

post "/expense/:id" do
  tx_id = Integer(params[:id])
  amount = BigDecimal(params[:amount])
  cat_id = Integer(params[:chosen_category])
  old_cat_id = Integer(params[:old_category])
  notes = params[:notes]

  DB.transaction do
    DB[:transactions].where(transaction_id: tx_id).update(amount: amount)
    DB[:categories_transactions].where(category_id: old_cat_id, transaction_id: tx_id).delete
    DB[:categories_transactions].insert(category_id: cat_id, transaction_id: tx_id)
    unless notes.nil? then
      DB[:transaction_notes].where(transaction_id: tx_id).update(note: notes)
    end
  end
  redirect "/expense/#{tx_id}"
end

get "/expense/:id/delete" do
  @tx_id = Integer(params[:id])
  haml :delete_expense
end

post "/expense/:id/delete" do
  tx_id = Integer(params[:id])
  DB.transaction do
    DB[:transaction_notes].where(transaction_id: tx_id).delete
    DB[:categories_transactions].where(transaction_id: tx_id).delete
    DB[:transactions].where(transaction_id: tx_id).delete
  end
  redirect "/"
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
    if budget != 0 then
      DB[:category_budgets].insert_conflict(:replace).
        insert(budget: budget, category_id: id)
    end
  end

  redirect "/category/create"
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
