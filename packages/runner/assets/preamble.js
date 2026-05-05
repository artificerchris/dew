(function () {
  const context = globalThis.__dewContext || {};
  const args = globalThis.__dewArgs || [];

  const format = (value) => {
    if (value === undefined) {
      return 'undefined';
    }
    if (value === null) {
      return 'null';
    }
    if (typeof value === 'string') {
      return value;
    }
    try {
      return JSON.stringify(value);
    } catch (_) {
      return String(value);
    }
  };

  if (globalThis.dew === undefined) {
    globalThis.dew = {};
  }

  const dew = globalThis.dew;

  dew.context = context;
  dew.args = args;

  const write = (prefix, values) => {
    const message = prefix
      ? [prefix, ...values].map(format).join(' ')
      : values.map(format).join(' ');
    if (typeof print === 'function') {
      print(message);
      return;
    }
    if (typeof console !== 'undefined' && typeof console.log === 'function') {
      console.log(message);
    }
  };

  dew.LogLevel = {
    trace: 'trace',
    debug: 'debug',
    info: 'info',
    warn: 'warn',
    error: 'error',
    fatal: 'fatal',
  };
  Object.freeze(dew.LogLevel);

  dew.console = {
    log: (level, ...values) => level === undefined || level === null ? write('', values) : write(`[${level}]`, values),
    trace: (...values) => dew.console.log(dew.LogLevel.trace, values),
    debug: (...values) => dew.console.log(dew.LogLevel.debug, values),
    info: (...values) => dew.console.log(dew.LogLevel.info, values),
    warn: (...values) => dew.console.log(dew.LogLevel.warn, values),
    error: (...values) => dew.console.log(dew.LogLevel.error, values),
    fatal: (...values) => dew.console.log(dew.LogLevel.fatal, values),
  }
  Object.freeze(dew.console);

  Object.freeze(dew);
})();
