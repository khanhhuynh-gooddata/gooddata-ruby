# encoding: UTF-8
#
# Copyright (c) 2010-2017 GoodData Corporation. All rights reserved.
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

shared_examples 'a user filter deleter' do
  it 'deletes the filter' do
    expect(existing_filter).to receive(:delete)
    result = subject.execute_mufs(filter_definitions, options)
    expect(result[:deleted].length).to be(1)
  end
end

describe GoodData::UserFilterBuilder do
  describe '.execute_mufs' do
    let(:login) { 'rubydev+admin@gooddata.com' }
    let(:full_definition_filter) do
      {
        :login => login,
        :filters => [{
          :label => label_id,
          :over => nil,
          :to => nil,
          :values => ["Washington"]
        }]
      }
    end

    let(:label_id) { 'label.csv_policies.state' }
    let(:label_uri) { '/gdc/md/wock3futg594lz3ornqv70yvbsivf896/obj/270' }
    let(:filter_definitions) { [full_definition_filter] }
    let(:options) do
      { client: client, project: project }
    end
    let(:users_brick_input) { [{ 'login' => login }] }
    let(:client) { double('client') }
    let(:domain) { double('domain') }
    let(:project) { double('project') }
    let(:user) { double('user') }
    let(:domain_user) { GoodData::Profile.new({"accountSetting" => {"links" => {  "self" => "domain_user@gmail.com" }}} ) }
    let(:project_users) { [user] }
    let(:label) { double('label') }
    let(:filter) { double('filter') }
    let(:existing_filter) { double('existing_filter') }
    let(:profile_url) { '/gdc/account/profile/foo' }

    before do
      allow(project).to receive(:labels).with(label_uri)
        .and_return(label)
      allow(project).to receive(:labels).with("label.csv_policies.state")
        .and_return(label)
      allow(project).to receive(:attributes)
      allow(project).to receive(:users).and_return(project_users)
      allow(project).to receive(:data_permissions).and_return([existing_filter])
      allow(project).to receive(:pid)
      allow(label).to receive(:values_count).and_return(666_666)
      allow(label).to receive(:uri).and_return(label_uri)
      allow(label).to receive(:find_value_uri).with('Washington').and_return('foo')
      allow(label).to receive(:attribute_uri).and_return('bar')
      allow(label).to receive(:identifier).and_return(label_id)
      allow(client).to receive(:create).and_return(filter)
      allow(client).to receive(:get)
        .and_return('userFilters' => { 'items' => [] })
      allow(client).to receive(:post)
        .and_return('userFiltersUpdateResult' => [])
      allow(filter).to receive(:related_uri)
      allow(existing_filter).to receive(:related_uri)
      allow(filter).to receive(:save)
      allow(filter).to receive(:uri)
      allow(user).to receive(:login).and_return(login)
      allow(user).to receive(:profile_url).and_return(login)
    end

    it 'resolves mufs to be created/deleted' do
      expect(existing_filter).to_not receive(:delete)
      result = subject.execute_mufs(filter_definitions, options)
      expect(result[:created].length).to be(1)
      expect(result[:deleted].length).to be(0)
    end

    context 'look for user' do
      let(:project_users) {[]}
      let(:options) do
        { client: client,
          project: project,
          domain: domain}
      end
      it 'found in domain' do
        allow(domain).to receive(:find_user_by_login).and_return(domain_user)
        result = subject.execute_mufs(filter_definitions, options)
        expect(result[:created].length).to be(1)
        expect(result[:deleted].length).to be(0)
      end
      it 'not found in domain' do
        allow(domain).to receive(:find_user_by_login).and_return(nil)
        result = subject.execute_mufs(filter_definitions, options)
        expect(result[:created].length).to be(1)
        expect(result[:deleted].length).to be(0)
      end
      it 'missing list > 100' do
        allow(domain).to receive(:find_user_by_login).and_return(domain_user)
        allow(domain).to receive(:users).and_return([domain_user])
        allow(domain).to receive(:name).and_return("domain_name")
        user_input = []
        for i in 0..101
          user_input << {
              :login => "user#{i}@email.com",
              :pid => "ProjectA"
          }
        end
        result = subject.execute_mufs(filter_definitions, options.merge(users_brick_input: user_input))
        expect(result[:created].length).to be(1)
        expect(result[:deleted].length).to be(0)
      end
    end

    context 'when dry_run option set to true' do
      let(:options) do
        { client: client,
          project: project,
          dry_run: true }
      end

      it 'does not alter filters' do
        expect(client).not_to receive(:post)
        subject.execute_mufs(filter_definitions, options)
      end

      it 'returns results' do
        result = subject.execute_mufs(filter_definitions, options)
        expected = [{ status: 'dry_run', user: nil, type: 'create' }]
        expect(result[:results]).to eq(expected)
      end
    end

    context 'when dry_run option set to false' do
      let(:options) do
        { client: client,
          project: project,
          dry_run: false }
      end

      it 'does alter filters' do
        expect(client).to receive(:post).with(
          "/gdc/md/#{project.pid}/userfilters",
          any_args
        )
        subject.execute_mufs(filter_definitions, options)
      end
    end

    context 'when users_brick_input option specified' do
      let(:user) { double('user') }
      let(:users_brick_input) { [{ 'login' => login }] }
      let(:options) do
        { client: client,
          project: project,
          users_brick_input: users_brick_input }
      end
      before do
        allow(project).to receive(:users).and_return([user])
        allow(user).to receive(:login).and_return(login)
        allow(user).to receive(:profile_url).and_return(profile_url)
      end

      context 'when filter has user in users_brick_input' do
        before do
          allow(existing_filter).to receive(:json)
            .and_return(related: profile_url)
        end
        it_behaves_like 'a user filter deleter'
        context 'when users_brick_input has symbols as keys' do
          let(:users_brick_input) { [{ login: login }] }
          it_behaves_like 'a user filter deleter'
        end
      end

      context 'when filter does not have user in users_brick_input' do
        before do
          allow(existing_filter).to receive(:json)
            .and_return(related: 'not_in_users_brick_input')
        end

        it 'does not delete filter' do
          result = subject.execute_mufs(filter_definitions, options)
          expect(result[:deleted]).to be_empty
        end
      end
    end

    context 'when creating MUFs results in errors' do
      before do
        allow(client).to receive(:post)
          .and_return 'userFiltersUpdateResult' => { 'failed' => [{ status: :failed }] }
      end

      it 'fails' do
        expect { subject.execute_mufs(filter_definitions, options) }.to raise_error(/Creating MUFs resulted in errors/)
      end
    end
  end
end
