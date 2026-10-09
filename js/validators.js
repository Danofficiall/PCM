export const Validators = {
  formatPlate(value, country = 'BR_MERCOSUL') {
    let clean = value.toUpperCase().replace(/[^A-Z0-9]/g, '');
    
    if (country === 'BR_MERCOSUL') {
      clean = clean.slice(0, 7);
      return clean;
    } else if (country === 'BR_OLD') {
      clean = clean.slice(0, 7);
      if (clean.length > 3) {
        return `${clean.slice(0, 3)}-${clean.slice(3)}`;
      }
      return clean;
    }
    return clean;
  },

  isValidPlate(value, country = 'BR_MERCOSUL') {
    const clean = value.replace(/[^A-Z0-9]/g, '');
    if (country === 'BR_MERCOSUL') {
      return /^[A-Z]{3}[0-9]{1}[A-Z]{1}[0-9]{2}$/.test(clean);
    } else if (country === 'BR_OLD') {
      return /^[A-Z]{3}[0-9]{4}$/.test(clean);
    }
    return clean.length >= 5;
  },

  formatCPF(value) {
    return value
      .replace(/\D/g, '')
      .slice(0, 11)
      .replace(/(\d{3})(\d)/, '$1.$2')
      .replace(/(\d{3})(\d)/, '$1.$2')
      .replace(/(\d{3})(\d{1,2})$/, '$1-$2');
  },

  isValidCPF(cpf) {
    const clean = cpf.replace(/\D/g, '');
    return clean.length === 11 && !/^(\d)\1+$/.test(clean);
  },

  formatRG(value) {
    return value
      .replace(/[^0-9xX]/g, '')
      .slice(0, 9)
      .replace(/(\d{2})(\d)/, '$1.$2')
      .replace(/(\d{3})(\d)/, '$1.$2')
      .replace(/(\d{3})([\dxX]{1,2})$/, '$1-$2');
  },

  isValidRG(rg) {
    const clean = rg.replace(/[^0-9xX]/g, '');
    return clean.length >= 8;
  },

  isValidEmail(email) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }
};
