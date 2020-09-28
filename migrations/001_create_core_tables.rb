Sequel.migration do
  up do
    create_table :categories do 
      primary_key :cat_id
      String :name, unique: true, null: false
    end

    create_table :category_group do
      primary_key :cat_grp_id
      String :name, unique: true, null: false
    end

    create_join_table(group_id: :category_groups, category_id: :categories)

    create_table :category_budgets do
      primary_key :cat_budget_id
      BigDecimal :budget, null: false
    end

    create_table :transactions do
      primary_key :transaction_id
      BigDecimal :amount, null: false
    end

    create_table :transaction_notes do
      primary_key :transaction_note_id
      foreign_key :transaction_id, :transactions
      String :note, null: false
    end

    create_table :images do
      primary_key :image_id
      String :path, null: false
    end

    # Creates :images_transactions table
    create_join_table(transaction_id: :transactions, image_id: :images)

  end

  def down
    drop_table(:category_group_categories)
    drop_table(:category_groups)
    drop_table(:category_budgets)
    drop_table(:categories)
    drop_table(:transaction_notes)
    drop_table(:images_transactions)
    drop_table(:transactions)
  end
end

