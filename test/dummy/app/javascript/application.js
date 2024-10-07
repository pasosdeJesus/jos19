/* eslint no-console:0 */

console.log('Hola Mundo desde ESM')

import Rails from "@rails/ujs";
import "@hotwired/turbo-rails"
Rails.start();
window.Rails = Rails

import "./jquery"
import 'popper.js'              // Dialogos emergentes usados por bootstrap
import * as bootstrap from 'bootstrap'              // Maquetacion y elementos de diseño

import TomSelect from 'tom-select';
window.TomSelect = TomSelect;
window.configuracionTomSelect = {
    create: false,
    diacritics: true, //no sensitivo a acentos
    sortField: {
          field: "text",
          direction: "asc"
        }
}

import Msip__Motor from "./controllers/msip/motor"
window.Msip__Motor = Msip__Motor
Msip__Motor.iniciar()
import Mr519Gen__Motor from "./controllers/mr519_gen/motor"
window.Mr519Gen__Motor = Mr519Gen__Motor
import Heb412Gen__Motor from "./controllers/heb412_gen/motor"
window.Heb412Gen__Motor = Heb412Gen__Motor
import Cor1440Gen__Motor from "./controllers/cor1440_gen/motor"
window.Cor1440Gen__Motor = Cor1440Gen__Motor
import Sivel2Gen__Motor from "./controllers/sivel2_gen/motor"
window.Sivel2Gen__Motor = Sivel2Gen__Motor

let esperarRecursosSprocketsYDocumento = function (resolver) {
  if (typeof window.puntomontaje == 'undefined') {
    setTimeout(esperarRecursosSprocketsYDocumento, 5, resolver)
    return false
  }
  if (document.readyState !== 'complete') {
    setTimeout(esperarRecursosSprocketsYDocumento, 5, resolver)
    return false
  }
  resolver("otros recursos manejados con sprockets cargados y documento presentado en navegador")
  return true
}

let promesaRecursosSprocketsYDocumento = new Promise((resolver, rechazar) => {
  esperarRecursosSprocketsYDocumento(resolver)
})

// Este se ejecuta cada vez que se carga una página que no está en cache 
// y tipicamente después de que se ha cargado la página completa y los recursos
promesaRecursosSprocketsYDocumento.then((mensaje) => {
  console.log('Cargando recursos sprockets')
  var root;
  root = window;
  msip_prepara_eventos_comunes(root, false, false);
  mr519_gen_prepara_eventos_comunes(root);
  heb412_gen_prepara_eventos_comunes(root);
  sivel2_gen_prepara_eventos_comunes(root);
  cor1440_gen_prepara_eventos_comunes(root);
  sivel2_gen_prepara_eventos_unicos(root);

  Msip__Motor.ejecutarAlCargarDocumentoYRecursos()
})


document.addEventListener('turbo:load', (e) => {
 /* Lo que debe ejecutarse cada vez que turbo cargue una página,
 * tener cuidado porque puede dispararse el evento turbo varias
 * veces consecutivas al cargarse  la misma página.
 */
  
  console.log('Escuchador turbo:load')

  msip_ejecutarAlCargarPagina(window)
  Msip__Motor.ejecutarAlCargarPagina()
})


import "./controllers"
