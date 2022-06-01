describe ManageIQ::Providers::Redhat::InfraManager::ProvisionViaIso do
  context "::StateMachine" do
    before do
      @ems = FactoryBot.create(:ems_redhat_with_authentication)
      template = FactoryBot.create(:template_redhat, :ext_management_system => @ems)
      @vm = FactoryBot.create(:vm_redhat, :ext_management_system => @ems)
      options  = {:src_vm_id => template.id}

      @task = FactoryBot.create(:miq_provision_redhat_via_iso, :source => template, :destination => @vm, :state => 'pending', :status => 'Ok', :options => options)
      allow(@task).to receive(:destination_image_locked?).and_return(false)
      @iso_image = FactoryBot.create(:iso_image, :name => "Test ISO Image")
      allow(@task).to receive(:update_and_notify_parent).and_return(nil)
      allow(@task).to receive(:iso_image).and_return(@iso_image)
    end

    include_examples "common rhev state machine methods"

    it "#configure_destination" do
      expect(@task).to receive(:attach_floppy_payload)
      expect(@task).to receive(:boot_from_cdrom)
      @task.configure_destination
    end

    describe "post provisioning" do
      let(:vm_service) { double("vm_service") }

      it "#post_provision" do
        allow(@vm).to receive(:with_provider_object).and_yield(vm_service)
        expect(vm_service).to receive(:update).with(:payloads => [])
        @task.post_provision
      end
    end

    describe "#boot_from_cdrom" do
      before do
        @ovirt_services = double("ovirt_services")
        allow(@ovirt_services).to receive(:vm_boot_from_cdrom).with(@task, @iso_image.name)
          .and_return(nil)
        allow(@ovirt_services).to receive(:powered_on_in_provider?).and_return(false)
        allow(@ems).to receive(:ovirt_services).and_return(@ovirt_services)
      end

      context "vm is ready" do
        it "#powered_on_in_provider?" do
          expect(@ovirt_services).to receive(:powered_on_in_provider?).with(@vm)
          @task.boot_from_cdrom
        end
      end

      context "vm is not ready" do
        before do
          exception = ManageIQ::Providers::Redhat::InfraManager::OvirtServices::VmNotReadyToBoot
          allow(@ovirt_services).to receive(:vm_boot_from_cdrom).with(@task, @iso_image.name)
            .and_raise(exception)
        end

        it "requeues the phase" do
          expect(@task).to receive(:requeue_phase)
          @task.boot_from_cdrom
        end
      end
    end
  end
end
