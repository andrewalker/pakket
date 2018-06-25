(function(){
  const CSS_CLASS_PAKKET_BAD = 'bad';
  const CSS_CLASS_PAKKET_FINE = 'ok';
  const CSS_CLASS_PAKKET_MISSING = 'missing';
  const CSS_CLASS_PAKKET_LATEST = 'latest';
  const CSS_CLASS_PAKKET_NOT_LATEST = 'not-latest';

  // actual rendering packages call
  renderPackages();

  function renderPackages() {
    const URL_FETCH_PAKKETS = '/all_packages';
    const localStorageKey = 'pakkets';
    // first checking if data is available at localStorage
    let pakketsInLocalStorage = localStorage.getItem(localStorageKey);
    if (pakketsInLocalStorage) {
      renderUI(JSON.parse(pakketsInLocalStorage));
      // updating cache if required
      $.ajax(URL_FETCH_PAKKETS).done(function(data) {
        const cachedPakketObject = JSON.stringify(data);
        if (pakketsInLocalStorage !== cachedPakketObject) {
          localStorage.setItem(localStorageKey, cachedPakketObject);
          // re-rendering UI
          renderUI(data);
        }
      });
    } else {
      // doing a plain ajax call
      $.ajax(URL_FETCH_PAKKETS).done(function(data) {
        renderUI(data);
        // and cache data to localstorage
        localStorage.setItem(localStorageKey, JSON.stringify(data));
      });
    }
  };

  function renderUI(data) {
    // taking pakket #1 and getting columns metadata from it
    const keys = Object.keys(data[0][1]);
    const desiredOrder = ['spec', 'source', '5.24.0', '5.24.3', '5.26.2'];
    let finalOrder = desiredOrder;
    let OSmetadata;
    keys.forEach((key) => {
      if (desiredOrder.indexOf(key) === -1) {
        finalOrder.push(key);
      }
      // getting OS metadata from first perl version prop
      if (strIsPerlVersion(key)){
        OSmetadata = Object.keys(data[0][1][key]).sort();
      }
    });

    let tableHead = '<tr>';
    tableHead += '<td class="name" rowspan="2" colspan="2">module name</td>';
    desiredOrder.forEach((column) => {
      // calculating colspan and rowspan
      let colspan = 1;
      let rowspan = 1;
      if (strIsPerlVersion(column)){
        colspan = 2;
      } else {
        rowspan = 2;
      }
      tableHead += `<td colspan="${colspan}" rowspan="${rowspan}">${column}</td>`;
    });
    tableHead += '</tr><tr>';
    desiredOrder.forEach((column) => {
      if (!strIsPerlVersion(column)) return;
      OSmetadata.forEach((os) => {
        tableHead += `<td>${os}</td>`;
      });
    });
    tableHead += '</tr>';
    // showing page title
    $('.hidden').removeClass('hidden');
    // required on re-render
    $('#thead').empty();
    $('#thead').append(tableHead);

    // calculating and rendering body
    let tableBody = '';
    const pakketsMap = new Map();
    // calculating pakketsMap - no rendering yet
    data.forEach((pakket) => {
      const nameFull = pakket[0];
      const namePieces = nameFull.split('=');
      const nameShort = namePieces[0];
      const version = namePieces[1];
      let mapVersions = pakketsMap.get(nameShort);
      mapVersions = mapVersions || [];
      if (mapVersions) {
        mapVersions.push(version);
      }
      pakketsMap.set(nameShort, mapVersions);
    });
    // actual rendering to a string
    data.forEach((pakket) => {
      const namePieces = pakket[0].split('=');
      tableBody += columnRenderer({
        name: namePieces[0],
        version: namePieces[1],
        order: desiredOrder,
        os_meta: OSmetadata,
        data: pakket,
        versions_all: pakketsMap.get(namePieces[0])
      });
    });

    // required on re-render
    $('#tbody').empty();
    $('#tbody').append(`${tableBody}`);
  }

  // helper functions
  // Is the string containing Perl version?
  function strIsPerlVersion(str) {
    return !isNaN(parseInt(str));
  }
  // Pakket table column renderer
  function columnRenderer(config) {
    const renderQueue = [];
    let problematicPakket = false;
    let versionsUI = '';
    const versionsArr = config.versions_all;
    versionsArr.forEach((version) => {
      versionsUI += `<option value="${version}" ${(version === config.version) ? 'selected' : ''}>${version}</option>`;
    });
    let tableRow = `<td class="name">${config.name}</td>
      <td class="version">${(versionsArr.length === 1 ? versionsArr[0] : ('<select data-name="' + config.name.replace(/[\/\.\:]/g,'') + '">' + versionsUI + '</select>'))}</td>`;
    config.order.forEach((column) => {
      if (strIsPerlVersion(column)){
        config.os_meta.forEach((os) => {
          renderQueue.push(config.data[1][column][os] ? '+' : '-');
        });
      } else {
        renderQueue.push(config.data[1][column] ? '+' : '-');
      }
    });
    // rendering queue
    renderQueue.forEach((val) => {
      tableRow += `<td ${(val === '+' ? '' : ('class="' + CSS_CLASS_PAKKET_MISSING + '"'))}>${val}</td>`;
    });
    // figuring out if pakket is problematic + reflecting in <tr> css class
    problematicPakket = !!renderQueue.filter(val => val === '-').length;
    const latestVersion = config.versions_all[config.versions_all.length - 1];
    return `<tr ${config.version !== latestVersion ? 'style="display: none;"' : ''}
      id="pak--${config.name.replace(/[\/\.\:]/g,'')}-${config.version.replace(/[\/\.\:]/g,'')}"
      class="${problematicPakket ? CSS_CLASS_PAKKET_BAD : CSS_CLASS_PAKKET_FINE}
            ${config.version === latestVersion ? CSS_CLASS_PAKKET_LATEST : CSS_CLASS_PAKKET_NOT_LATEST}">${tableRow}</tr>`;
  }

  $('#tbody').on('change', '.version select', function(e){
    const $target = $(e.target);
    const value = $target.val();
    const pakketName = $target.data('name');
    const $currRow = $target.parents('tr');
    const $select = $currRow.find('select');
    // hiding current row
    $currRow.hide();
    // re-shaking select UI
    const selectOptions = $select.html();
    $select.html(selectOptions);
    // showing new one
    $(`#pak--${pakketName}-${value.replace(/[\/\.\:]/g,'')}`).show();
  });

  $('#only-problematic').on('change', function(){
    // as we have grouping now - we need to show mandatory
    // broken pakkets initially
    $(`.${CSS_CLASS_PAKKET_BAD}`).show();
    if ($(this).is(':checked')) {
      $(`.${CSS_CLASS_PAKKET_FINE}`).hide();
    } else {
      $(`.${CSS_CLASS_PAKKET_FINE}`).show();
      // and hiding not latest versions
      $(`.${CSS_CLASS_PAKKET_NOT_LATEST}`).hide();
    }
  });

})();
