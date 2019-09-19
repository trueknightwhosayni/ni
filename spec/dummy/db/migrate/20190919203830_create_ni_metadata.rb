class CreateNiMetadata < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      ## Database authenticatable
      t.string :email,              null: false, default: ""
      t.string :password,           null: false, default: ""


      t.timestamps null: false
    end

    create_table :ni_metadata do |t|
      t.string :uid, null: false
      t.string :key, null: false
      t.datetime :run_timer_at
      t.text :data

      t.timestamps
    end

    add_index :ni_metadata, [:uid, :key], unique: true
  end
end
