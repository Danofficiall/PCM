import { Validators } from './validators.js';

const currentUser = {
  role: 'super_admin'
};

document.addEventListener('DOMContentLoaded', () => {
  setupUIPermissions();
  setupMasksAndValidations();
  setupPartnersDropdown();
  setupFormValidation();
});

function setupUIPermissions() {
  const devHeaderBtn = document.getElementById('dev-customize-header');
  const devFooterBtn = document.getElementById('dev-customize-footer');
  const adminLogoUpload = document.getElementById('admin-logo-upload-btn');

  if (currentUser.role !== 'super_admin') {
    if (devHeaderBtn) devHeaderBtn.style.display = 'none';
    if (devFooterBtn) devFooterBtn.style.display = 'none';
  }

  if (['super_admin', 'admin'].includes(currentUser.role)) {
    if (adminLogoUpload) adminLogoUpload.style.display = 'inline-block';
  } else {
    if (adminLogoUpload) adminLogoUpload.style.display = 'none';
  }
}

function setupMasksAndValidations() {
  const plateInput = document.getElementById('vehicle_plate');
  const countrySelect = document.getElementById('plate_country');

  if (plateInput) {
    plateInput.addEventListener('input', (e) => {
      const country = countrySelect ? countrySelect.value : 'BR_MERCOSUL';
      e.target.value = Validators.formatPlate(e.target.value, country);
    });
  }

  document.querySelectorAll('[data-mask="cpf"]').forEach(input => {
    input.addEventListener('input', (e) => e.target.value = Validators.formatCPF(e.target.value));
  });

  document.querySelectorAll('[data-mask="rg"]').forEach(input => {
    input.addEventListener('input', (e) => e.target.value = Validators.formatRG(e.target.value));
  });
}

function setupPartnersDropdown() {
  const partnersList = [
    { id: '1', name: 'Locadora Alfa', type: 'lessor' },
    { id: '2', name: 'Auto Peças Silva', type: 'supplier' }
  ];

  const lessorSelect = document.getElementById('lessor_select');
  const supplierSelect = document.getElementById('supplier_select');

  if (lessorSelect) {
    lessorSelect.innerHTML = '';
    lessorSelect.appendChild(new Option('Selecione um locador...', ''));
    
    partnersList
      .filter(p => p.type === 'lessor' || p.type === 'both')
      .forEach(p => {
        lessorSelect.appendChild(new Option(p.name, p.id));
      });
  }

  if (supplierSelect) {
    supplierSelect.innerHTML = '';
    supplierSelect.appendChild(new Option('Selecione um fornecedor...', ''));
    
    partnersList
      .filter(p => p.type === 'supplier' || p.type === 'both')
      .forEach(p => {
        supplierSelect.appendChild(new Option(p.name, p.id));
      });
  }
}

function setupFormValidation() {
  const forms = document.querySelectorAll('form');

  forms.forEach(form => {
    form.addEventListener('submit', (e) => {
      let isValid = true;
      const inputs = form.querySelectorAll('input, select, textarea');

      inputs.forEach(input => {
        if (input.name === 'notes' || input.id === 'notes') {
          return;
        }

        if (!input.value.trim()) {
          isValid = false;
          input.classList.add('is-invalid');
        } else {
          input.classList.remove('is-invalid');
        }

        if (input.dataset.mask === 'cpf' && !Validators.isValidCPF(input.value)) {
          isValid = false;
          alert('Por favor, insira um CPF válido com a quantidade correta de caracteres.');
          input.classList.add('is-invalid');
        }

        if (input.dataset.type === 'plate') {
          const country = document.getElementById('plate_country')?.value || 'BR_MERCOSUL';
          if (!Validators.isValidPlate(input.value, country)) {
            isValid = false;
            alert('A placa informada não atende ao número e formato de caracteres do país selecionado.');
            input.classList.add('is-invalid');
          }
        }
      });

      if (!isValid) {
        e.preventDefault();
      }
    });
  });
}
