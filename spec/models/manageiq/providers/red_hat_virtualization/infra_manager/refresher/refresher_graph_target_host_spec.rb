require_relative 'ovirt_refresher_spec_common'

describe ManageIQ::Providers::Redhat::InfraManager::Refresher do
  include OvirtRefresherSpecCommon

  describe ManageIQ::Providers::Redhat::InfraManager::Refresher do
    before(:each) do
      init_defaults(:hostname => "pluto-vdsg.eng.lab.tlv.redhat.com", :ipaddress => "10.35.19.13", :port => 443)
      init_connection_vcr('spec/vcr_cassettes/manageiq/providers/red_hat_virtualization/infra_manager/refresh/ovirt_sdk_refresh_graph_target_host.yml')

      @ovirt_service_inventory = ManageIQ::Providers::Redhat::InfraManager::Inventory
      allow_any_instance_of(@ovirt_service_inventory)
                       .to receive(:collect_vnic_profiles).and_return([])
      @collector = ManageIQ::Providers::Redhat::Inventory::Collector
      allow_any_instance_of(@collector)
                       .to receive(:collect_vnic_profiles).and_return([])
    end

    let(:models_for_host_target) { [ExtManagementSystem, EmsFolder, EmsCluster, Storage, HostStorage, Switch, HostSwitch, Lan, CustomAttribute] }

    it 'does not change the host when target refresh after full refresh' do
      EmsRefresh.refresh(@ems)
      @ems.reload

      saved_inventory = serialize_inventory(models_for_host_target)

      host = @ems.hosts.find_by(:ems_ref => "/api/hosts/9be35c00-6523-4c2f-89d2-680a6b6da4c0")
      EmsRefresh.refresh(host)
      host.reload
      expect(serialize_inventory(models_for_host_target)).to eq(saved_inventory)
      host.update_attribute(:ipmi_address, "127.0.0.1")
      host.update_authentication(:ipmi => {:userid => "a", :password => "a"})
      EmsRefresh.refresh(host)
      host.reload

      expect(Host.count).to eq(2)
      expect(host.ipmi_address).to eq("127.0.0.1")
      expect(host.authentications.first.userid).to eq("a")
      expect(host.switches.map { |switch| [switch.uid_ems, switch.name] }).to contain_exactly(
        a_collection_containing_exactly("b6a660fd-f1ff-4d26-b535-91fae6d42a3f", "ovirtmgmt")
      )
    end

    def host_to_comparable_hash(host)
      host.attributes.except("updated_on", "state_changed_on")
    end
  end
end
