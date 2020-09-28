Sequel.migration do
	up do
		alter_table(:category_budgets) do
			add_foreign_key :category_id, :categories
		end
	end
  down do
    drop_column :category_budgets, :category_id
  end
end