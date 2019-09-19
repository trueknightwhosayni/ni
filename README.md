# Ni

## The Developers Who Say Ni [nee]

- What it the easiest way to build a service with ruby?
- Ni
- What it the most convinient way to implement any business logic flow?
- Ni
- How can I stop care about the flow control and focus on things are really matter?
- Ni
- How can I build an ERP, CRM, BPM and other three letter things?
- Ni + Peng + NeeeWom => Graal

## Warning

Because of my strong intentions to try these ideas in the real world projects ASAP sometimes I didn't have enough time for solid solutions or decent tests. So, please use only DSL described below. If it doesn't allows you to solve your issues, do not use interactor then

All things described below are possible because of the ruby power. A lot metaprogrammings and high complexity code under the hood Ni to implement whatever flow you need. But, in some cases I've add additional stricts, which should not allow you to make a bad choices. They are described as **Strict! Bold text ...**

## Features

### The most simple interactor

```ruby
class Interactor
  include Ni::Main

  receive :param_1

  def perform
    self.context.errors.add(:base, 'An error') if context.param_1 == '2'
  end
end

result = Interactor.perform(param_1: '1')

result.success? # false
```

Or with using the chain DSL. The chain DSL allows all power of Ni to comes in

```ruby
class Interactor
  include Ni::Main

  receive :param_1

  action :perform do
    self.context.errors.add(:base, 'An error') if context.param_1 == '2'
  end
end

result = Interactor.perform(param_1: '1')

result.success? # false
```

### Interactor result

You can get any context value via the context method.
But, there is also another method to read the context values with assign multiple variables

```ruby
class Interactor
  include Ni::Main

  provide :a
  provide :b
  provide :c

  action :perform do
    context.a = 1
    context.b = 2
    context.c = 3
  end
end

result = Interactor.perform

result.success? #  true
result.context.a # 1
result.context.b # 2
result.context.c # 3

result, a, b, c = Interactor.perform
a # 1
b # 2
c # 3
```

But, if the list of provided values will be specified manually, only these params will be returned. Check the `provide(:c)` part of the chain
```ruby
class Interactor
  include Ni::Main

  provide :a
  provide :b
  provide :c

  action :perform do
    context.a = 1
    context.b = 2
    context.c = 3
  end
  .provide(:c)
end

result, c = Interactor.perform

result.context.a # 1
result.context.b # 2
c # 3
```

### Interactor context and contracts

Shared state is one of the Interactor pattern cons. To control it Ni has access and contract DSL.
You can't manipulate with the context data without explicitly defining your intentions.

The `receive` allows to read from context.
The `mutate` allows to read and write.
The `provide` allows only to write.

**Note! If there are no any rules then all access granted!**

```ruby
class Interactor1
  include Ni::Main

  action :perform do
    context.param_1
  end
end

class Interactor2
  include Ni::Main

  receive :param_1

  action :perform do
    context.param_2 = context.param_1
  end
end

Interactor1.perform(param_1: 1) # will not raise any exceptions
Interactor2.perform(param_1: 1) # will raise "The `param_2` is not allowed to write"
```

Please note that defining read/write rules are not working as a contracts.

```ruby
class Interactor
  include Ni::Main

  receive :param_1
  mutate :param_2
  provide :param_3

  action :perform do
    #do nothing
  end
end

result = Interactor.perform
result.success? # true
```

You can define contracts with two different ways:

Method contracts

```ruby
class Interactor
  include Ni::Main

  receive :param_1, :present?
  mutate :param_2, :zero?
  provide :param_3, :zero?

  action :perform do
    context.param_3 = 1
  end
end

Interactor.perform # will raise "Value of `param_1` doesn't match to contract :present?"
Interactor.perform(param_1: true, param_2: 1) # will raise "Value of `param_2` doesn't match to contract :zero?"
Interactor.perform(param_1: true, param_2: 0) # will raise "Value of `param_3` doesn't match to contract :zero?"
```

Lambda contracts

```ruby
class Interactor
  include Ni::Main

  receive :param_1, -> (val) { val == true }
  mutate :param_2, -> (val) { val == 0 }
  provide :param_3, -> (val) { val == 0 }

  action :perform do
    context.param_3 = 1
  end
en

Interactor.perform # will raise "Value of `param_1` doesn't match to contract"
Interactor.perform(param_1: true, param_2: 1) # will raise "Value of `param_2` doesn't match to contract"
Interactor.perform(param_1: true, param_2: 0) # will raise "Value of `param_3` doesn't match to contract"
```

### An actions DSL

```ruby
class Interactor1
  include Ni::Main

  receive :param_1

  action :perform do
    self.context.errors.add(:base, 'An error') if context.param_1 == '2'
  end
end
```

 You can define new actions based on the existing ones

 ```ruby
 class Interactor
    include Ni::Main

    receive :custom_option
    mutate :param_1

    action :create do
      if context.custom_option
        context.param_1 = 'new_value_1'
      else
        context.param_1 = 'new_value'
      end
    end

    def self.create!(params={})
      create params.merge(custom_option: true)
    end
  end

  result = Interactor.create!(param_1)
  result.context.param_1 # new_value_1
 ```

 Or, even redefine an interface

 ```ruby
 class Interactor
    include Ni::Main

    receive :custom_option
    mutate :param_1

    action :create do
      if context.custom_option
        context.param_1 = 'new_value_1'
      else
        context.param_1 = 'new_value'
      end
    end

    def self.create(params={})
      perform_custom :create, params.merge(custom_option: true)
    end
  end

  result = Interactor.create!(param_1)
  result.context.param_1 # new_value_1
 ```

There are two callbacks which called when need to check a condition `on_checking_continue_signal` and `on_continue_signal_checked`. You can use them to get an additional control for your flow

```ruby
class Organizer
  include Ni::Main

  storage Ni::Storages::Default
  metadata_repository Ni::Storages::ActiveRecordMetadataRepository

  mutate :user_1
  mutate :user_2
  mutate :before_cheking
  mutate :after_cheking

  action :perform do
    context.user_1 = User.create! email: 'user1@test.com', password: '111111'
  end
  .then(:create_second_user)
  .wait_for(:outer_action_performed)

  private

  def on_checking_continue_signal(unit)
    context.before_cheking = User.where(email: 'before@test.com').first_or_create! password: '111111'
  end

  def on_continue_signal_checked(unit, wait_cheking_result)
    context.after_cheking = User.where(email: 'after@test.com').first_or_create! password: '111111'
  end

  def create_second_user
    context.user_2 = User.create! email: 'user2@test.com', password: '111111'
  end
end
```

### Callbacks

When you use an action DSL you can define a callbacks. The Ni will call it automatically.

**Note! All actions will have the same callbacks and will receive action name as an argument**

```ruby
class Interactor
  include Ni::Main

  mutate :param_1
  mutate :param_2
  mutate :param_3

  def before_action(name)
    if name == :perform
      context.param_1 = 'perform_1'
    else
      context.param_1 = 'custom_perform_1'
    end
  end

  def after_action(name)
    if name == :perform
      context.param_3 = 'perform_3'
    else
      context.param_3 = 'custom_perform_3'
    end
  end

  action :perform do
    context.param_2 = 'perform_2'
  end
  .provide(:param_1, :param_2, :param_3)

  action :custom_perform do
    context.param_2 = 'custom_perform_2'
  end
  .provide(:param_1, :param_2, :param_3)
end

result, param_1, param_2, param_3 = Interactor.perform

param_1 # 'perform_1'
param_2 # 'perform_2'
param_3 # 'perform_3'

result, param_1, param_2, param_3 = Interactor.custom_perform

param_1 # 'custom_perform_1'
param_2 # 'custom_perform_2'
param_3 # 'custom_perform_3'
```

### Organizers

Ni allows to build your domain flow. It has a super simple DSL for organizing Interactors into a chains.

```ruby
class Interactor2
  include Ni::Main

  receive :param_2
  provide :param_3

  def perform
    context.param_3 = context.param_2 + 1
  end
end

class Interactor3
  include Ni::Main

  receive :param_4
  provide :param_5

  action :custom_action do
    context.param_5 = context.param_4 + 1
  end
end

class Interactor
  include Ni::Main

  mutate :param_1
  mutate :param_2
  mutate :param_3
  mutate :param_4
  mutate :param_5
  mutate :final_value

  action :perform do
    context.param_1 = 1
  end
  .then(:step_1)
  .then(Interactor2)
  .then do
    context.param_4 = context.param_3 + 1
  end
  .then(Interactor3, :custom_action)
  .then(:step_2)
  .then do
    context.final_value = context.param_5 + 1
  end

  private

  def step_1
    context.param_2 = context.param_1 + 1
  end

  def step_2
    context.param_5 = context.param_4 + 1
  end
end

result = Interactor.perform

result.context.param_1 # 1
result.context.param_2 # 2
result.context.param_3 # 3
result.context.param_4 # 4
result.context.param_5 # 5
result.context.final_value # 6
 ```

### Context Isolation

Building application within the set of small reusable modules are good approach. This is exactly what interactor pattern means - follow the SRP principle. Use each Interactor independently or gather them into Organizer chain.
The contracts will help you to keep your code solid.

But, there are a case, when a shared state could be an issue. Because the DSL allows you to build and combine interactors in any way you want with a single interface, you can face the situation when one chain will perform another one as it's step. So, in this case the step will be not a single Interactor, but a chain of the another ones.

And this second chain can contain interactors, which changes the same params. Or just contain the same Interactors.

In this case you can perform it in isolation.

```ruby
class Interactor2
  include Ni::Main

  mutate :param_1
  provide :param_2

  action :custom_action do
    context.param_2 = context.param_1 + 1
    context.param_1 = 25
  end
end

class Organizer1
  include Ni::Main

  mutate :param_1
  mutate :param_2
  mutate :param_3

  action :perform do
    # an empty initializer
  end
  .then(Interactor1)
  .isolate(Interactor2, :custom_action, receive: [:param_1], provide: [:param_2])
  .then(Interactor3)
end
```

The `Interactor2` can't change `param_1` value. The `Interactor3` will receive original `param_1` value.

### Errors and Exceptions

The Ni has a DSL to control the flow and exceptions when performing the chain.

To stop the interaction execution just add an error to context. Also you could specify the failure callback

```ruby
class Interactor1
  include Ni::Main

  def perform
    context.errors.add :base, 'Something went wrong'
  end
end

class Interactor2
  include Ni::Main

  provide :param_1

  def perform
    context.param_1 = 1
  end
end

class Organizer1
  include Ni::Main

  provide :failure_value

  action :perform do
    # empty initializer
  end
  .then(Interactor1)
  .then(Interactor2)
  .failure do
    context.failure_value = 'fail'
  end
end

result = Organizer1.perform

result.success? # false
result.context.param_1 # nil
result.context.failure_value # 'fail'
```

Also allows to handle exceptions. Check the `rescue_from` section. You can specify the exceptions handlers or specify the default handler for all exceptions.

```ruby
class Ex1 < Exception
end

class Ex2 < Exception
end

class Interactor1
  include Ni::Main

  def perform
    raise Es::Ex2.new
  end
end

class Interactor2
  include Ni::Main

  provide :param_1

  def perform
    context.param_1 = 1
  end
end

class Organizer1
  include Ni::Main

  provide :exception_value

  action :perform do
    # empty initializer
  end
  .then(Es::Interactor1)
  .then(Es::Interactor2)
  .rescue_from Es::Ex1, Es::Ex2 do
    context.exception_value = 'fail'
  end
end

class Organizer2
  include Ni::Main

  provide :exception_value

  action :perform do
    # empty initializer
  end
  .then(Es::Interactor1)
  .then(Es::Interactor2)
  .rescue_from do
    context.exception_value = 'fail'
  end
end

result = Organizer1.perform

result.success? # false
result.context.param_1 # eq nil
result.context.exception_value # 'fail'
```

### Pause your flow

Ni allows you to pause your flow and continue it later. Ni will do the job, but it will require some configuration.

When chain meets the `wait_for(:outer_action_performed)` it stops the chain performance. Then you can call the same method and pass two options to tell Ni that you want to continue your performance, but not to start a new one

**Strict! The `:outer_action_performed` not just a human readable name, but also an unique ID and it's global for the whole application. You can't use the same names in different interactors!**

```ruby
Organizer.perform(wait_completed_for: :outer_action_performed, system_uid: uid)
```

The uid you can get from the previous interactor execution. It's stored in context as `system_uid`. It will not just continue the performance, but also will restore yours context, if you want.

Also you can set the multiple conditions and even add a dynamic condition.

```ruby
wait_for(more_users_expected:
  [
    :moderator_user_registered,
    [:user_registration, -> (context) { User.count >= 6 }]
  ]
)
```

The `more_users_expected` is just a syntax key. To back to this steps you need to use a symbol names from the described conditions.

```ruby
Organizer.perform(wait_completed_for: :moderator_user_registered, system_uid: uid)
Organizer.perform(wait_completed_for: :user_registration, system_uid: uid)
```

In the example above you need to pass the `:user_registration` until you will have 6 users. But please be aware, you should stop calling the interactor by yourself, when the condition becomes wrong. For now Ni has no any internal logic to track when conditions becomes irrelevant

Also you need to know about multiple conditions it's that the Metadata Repository is required. What is it will be described right after the code example.

```ruby
class Organizer
  include Ni::Main

  storage Ni::Storages::Default
  metadata_repository Ni::Storages::ActiveRecordMetadataRepository

  mutate :user_1
  mutate :user_2
  mutate :user_3
  mutate :admin_user
  mutate :done

  action :perform do
    context.user_1 = User.create! email: 'user1@test.com', password: '111111'
  end
  .then(:create_second_user)
  .wait_for(:outer_action_performed)
  .then(:create_third_user)
  .wait_for(more_users_expected:
    [
      :moderator_user_registered,
      [:user_registration, -> (context) { User.count >= 6 }]
    ]
  )
  .then(:create_admin)
  .wait_for(:all_thigs_done)
  .then do
    context.done = true
  end

  private

  def create_second_user
    context.user_2 = User.create! email: 'user2@test.com', password: '111111'
  end

  def create_third_user
    context.user_3 = User.create! email: 'user3@test.com', password: '111111'
  end

  def create_admin
    context.admin_user = User.create! email: 'admin@test.com', password: '111111'
  end
end

first_result = Organizer.perform.context
uid = first_result.system_uid

first_result.user_1.email # 'user1@test.com'
first_result.user_2.email #'user2@test.com'
first_result.user_3       # nil

second_result = Organizer.perform(wait_completed_for: :outer_action_performed, system_uid: uid).context

second_result.user_1.email # 'user1@test.com'
second_result.user_2.email # 'user2@test.com'
second_result.user_3.email # 'user3@test.com'
second_result.admin_user   # nil

User.create! email: 'moderator@test.com', password: '111111'

# The third result will be the same because users count less then 6
third_result = Organizer.perform(wait_completed_for: :moderator_user_registered, system_uid: uid).context
third_result.user_1.email # 'user1@test.com'
third_result.user_2.email # 'user2@test.com'
third_result.user_3.email # 'user3@test.com'
third_result.admin_user   # nil

User.create! email: 'user4@test.com', password: '111111'

# The fourth result will be the same because need one more user
fourth_result = Organizer.perform(wait_completed_for: :user_registration, system_uid: uid).context
fourth_result.user_1.email # 'user1@test.com'
fourth_result.user_2.email # 'user2@test.com'
fourth_result.user_3.email # 'user3@test.com'
fourth_result.admin_user   # nil

User.create! email: 'user5@test.com', password: '111111'

# Now the admin creation is available
result = Organizer.perform(wait_completed_for: :user_registration, system_uid: uid).context
result.user_1.email # 'user1@test.com'
result.user_2.email # 'user2@test.com'
result.user_3.email # 'user3@test.com'
result.admin_user.email # 'admin@test.com'
result.done         # nil

# This last step checks that skip for multiple conditions work as well
result = Organizer.perform(wait_completed_for: :all_thigs_done, system_uid: uid).context
result.done # true
```

It's smart enough to get, that the wait part is not in the top level flow. For example Organizer1 calls Organizer2 as a step and Organizer2 has the `wait_for` part.

More detailed example. The Organizer interactor uses the OrganizerLevel2 one. The OrganizerLevel2 interactor uses the OrganizerLevel3 one. Each of them has own `wait_for` logic. And it works correct, because Ni recursively parse the interactors tree and use it to control it's flow.

```ruby
class OrganizerLevel3
  include Ni::Main

  storage Ni::Storages::Default
  metadata_repository Ni::Storages::ActiveRecordMetadataRepository

  mutate :user_3

  action :perform do
    # empty initializer
  end
  .wait_for(:ready_create_third_user)
  .then do
    context.user_3 = User.create! email: 'user3@test.com', password: '111111'
  end
end

class OrganizerLevel2
  include Ni::Main

  storage Ni::Storages::Default
  metadata_repository Ni::Storages::ActiveRecordMetadataRepository

  mutate :user_2

  action :perform do
    # empty initializer
  end
  .wait_for(:ready_create_second_user)
  .then do
    context.user_2 = User.create! email: 'user2@test.com', password: '111111'
  end
  .then(OrganizerLevel3)
end

class Organizer
  include Ni::Main

  storage Ni::Storages::Default
  metadata_repository Ni::Storages::ActiveRecordMetadataRepository

  mutate :user_1
  mutate :user_2
  mutate :user_3
  mutate :admin_user
  mutate :done

  action :perform do
    context.user_1 = User.create! email: 'user1@test.com', password: '111111'
  end
  .then(OrganizerLevel2)
  .wait_for(:ready_create_admin)
  .then(:create_admin)
  .wait_for(:final_step)
  .then do
    context.done = true
  end

  private

  def create_admin
    context.admin_user = User.create! email: 'admin@test.com', password: '111111'
  end
end

first_result = Sowf::Organizer.perform.context
uid = first_result.system_uid

first_result.user_1.email # 'user1@test.com'
first_result.user_2 # nil
first_result.user_3 # nil

second_result = Sowf::Organizer.perform(wait_completed_for: :ready_create_second_user, system_uid: uid).context

second_result.user_1.email # 'user1@test.com'
second_result.user_2.email # 'user2@test.com'
second_result.user_3 # nil
second_result.admin_user # nil

second_result = Sowf::Organizer.perform(wait_completed_for: :ready_create_third_user, system_uid: uid).context

second_result.user_1.email # 'user1@test.com'
second_result.user_2.email # 'user2@test.com'
second_result.user_3.email # 'user3@test.com'
second_result.admin_user # nil

# Now the admin creation is available
result = Sowf::Organizer.perform(wait_completed_for: :ready_create_admin, system_uid: uid).context
result.user_1.email # 'user1@test.com'
result.user_2.email # 'user2@test.com'
result.user_3.email # 'user3@test.com'
result.admin_user.email # 'admin@test.com'
result.done # nil

# This last step checks that skip for multiple conditions work as well
result = Sowf::Organizer.perform(wait_completed_for: :final_step, system_uid: uid).context
result.done # true
```

So, in this example you may notice the two new configurations: Storage and Metadata Repository.

```ruby
storage Ni::Storages::Default
metadata_repository Ni::Storages::ActiveRecordMetadataRepository
```

The Storage class implements logic for storing your context and restoring it. There is a default storage `Ni::Storages::Default` you can use. For now it supports only the ActiveRecord records and collections, relations and so one.

But it's easy to implement your own one. Just create a new class, inherite from `Ni::Storages::Default`. And you will have a two option, how to work with context. Check the `storages/default_spec.rb` to get an examples.

The Metadata Repository needed to store some metadata. I.e. for Storage it will store the metadata, which will allow to restore you context. For the multiple wait_for it will store the list of already passed conditions.

Ni has an implemented ActiveRecord repository, which can be used with rails. Just create a relavant table for it.

```ruby
create_table :ni_metadata do |t|
  t.string :uid, null: false
  t.string :key, null: false
  t.datetime :run_timer_at
  t.text :data

  t.timestamps
end

add_index :ni_metadata, [:uid, :key], unique: true
```

These classes has a pretty simple interfaces, so it will be easy to develop your own ones for your needs.

### Unique IDs

Interactors can have an explicit `unique_id`. This will allow to use an identifier when building your flow. I.e. the WaitFor could receive interactor class as an option, if the unique id was provided.

Unique_id should be a symbol. By default it's a class name.

```ruby
class Interactor1
  include Ni::Interactor
end
class Interactor2
  include Ni::Interactor

  unique_id :some_unique_id
end

Interactor1.interactor_id # 'Interactor1'
Interactor1.interactor_id! # Will raise "The Interactor1 requires an explicit definition of the unique id"

Interactor2.interactor_id # :some_unique_id
Interactor2.interactor_id! # :some_unique_id
```

The WaitFor example

```ruby
class ExternalThirdUser
  include Ni::Main

  unique_id :external_third_user

  action :perform do
  end
end

class OrganizerLevel3
  include Ni::Main

  storage Ni::Storages::Default
  metadata_repository Ni::Storages::ActiveRecordMetadataRepository

  mutate :user_3

  action :perform do
    # empty initializer
  end
  .wait_for(Sowf::ExternalThirdUser)
  .then do
    context.user_3 = User.create! email: 'user3@test.com', password: '111111'
  end
end
```

It doesn't matter how to continue chain, by a symbol ID or providing a class

### Flow branches

Describing a flow you may face with the situation when flow splits to several branches and it depends on some conditions which one will be performed.

There are two ways to define a branch.

1. Use an existing Interactor.
2. Use a branch id

```ruby
action :perform do
end
.branch(SomeExistingInteractor, when: -> (context) { context.param_1 == 666 })
.branch(:first_level_valid_branch, when: -> (context) { context.param_1 == 1 }) do
  receive :param_1

  action :perform do
  end
end
```

In both cases you need to specify a when condition by defining a lambda. Branches supports all features of the interactors, like WaitFor and others.

**There are some pitfals with branches. Because all interactors share a single state, the first branch may change the context and made the second one also valid**

More detailed example

```ruby
class Level1NotUsedBranch
  include Ni::Main

  def perform
    raise 'Should not be here'
  end
end

class Level2NotUsedBranch
  include Ni::Main

  def perform
    raise 'Should not be here'
  end
end

class Organizer1
  include Ni::Main

  mutate :param_1

  action :perform do
    context.param_1 = 1
  end
    .branch(Level1NotUsedBranch, when: -> (context) { context.param_1 == 666 })
    .branch :first_level_valid_branch, when: -> (context) { context.param_1 == 1 } do

      receive :param_1

      action :perform do
      end
        .branch :second_level_valid_branch, when: -> (context) { context.param_1 == 1 } do
          mutate :param_1

          action :perform do
            context.param_1 = 2
          end
        end
        .branch(Level2NotUsedBranch, when: -> (context) { context.param_1 == 666 })
    end
end

expect(Organizer1.perform.context.param_1 # 2
```



### TODO:

Continue logic:
  - For now Ni has no any internal logic to track when conditions becomes irrelevant
Parallel execution
Implement some wrap logic. I.e. a way to put operations in transaction
Ensure all features will also work for the Ancestors

Allow to break execution with success or failure, cancel or terminate
- fix tests
- Chain methods
- Inline flow + Branches
- Refactoring to allow just a simple methods, not only from chain

```ruby

class Organizer1
  include Ni::Main

  provide :failure_value

  storage CustomStorage
  metadata_repository MetadataRepository

  action :perform do
    # empty initializer
  end
  .then(Interactor1, on_cancel: CancelInteractor, on_failure: FailureInteractor, on_terminate: TerminateInteractor) # Same for branches
  .wait_for(:interactor2_ready)
  .then(Interactor2)
  .async(continue_from: :interactor10_ready,
    steps: [
      Interactor3,
      [Intreractor4, :custom_action]
    ]
  )
  .wait_for(:interactor10_ready)
  .handoff_to('Remote microservice',
    via: MyHTTPChannel,
    continue_from: :interactor11_ready
  )
  .wait_for(:interactor11_ready)
  .then(Interactor11)
    .branch :my_new_branch, when: -> (context) { context.param_1 == 1 } do
      action :perform do
      end
      .then(Interactor12)
      .wait_for(:interactor13_ready)
      .then(Interactor13)
      .cancel!
    end
    .branch :other_branch, when: -> (context) { context.param_1 == 2 } do
      action :perform do
      end
      .then(Interactor14)
        .branch :inner_branch, when: -> (context) { context.param_1 == 1 } do
          action :perform do
          end
          .then(Interactor15)
        end
        .branch(Intreractor4, :custom_action, when: -> (context) { context.param_1 == 1 })
        .terminate!

    end
  .wait_for(
    all_ready: [
      :interactor15,
      [:interactor16, -> (context) { context.param_1 == '10' } ],
      :interactor17
    ],
    timer: [ -> { 10.minutes.from_now }, InteractorTimer, :custom]
  )
  .failure do
    context.failure_value = 'fail'
  end
end
```

