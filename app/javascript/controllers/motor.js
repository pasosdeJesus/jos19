
export default class Jos19__Motor {
  /* 
   * Librería de funciones comunes.
   * Aunque no es un controlador lo dejamos dentro del directorio
   * controllers para aprovechar método de msip para compartir controladores
   * Stimulus de motores.
   *
   * Como su nombre no termina en _controller no será incluido en 
   * controllers/index.js
   *
   * Desde controladores stimulus importelo con
   *
   *  import Jos19__Motor from "../jos19/motor"
   *
   * Use funciones por ejemplo con
   *
   *  Jos19__Motor.ejecutarAlCargarPagina()
   *
   * Para poderlo usar desde Javascript global con window.Jos19__Motor 
   * asegure que en app/javascript/application.js ejecuta:
   *
   * import Jos19__Motor from './controllers/jos19/motor.js'
   * window.Jos19__Motor = Jos19__Motor
   *
   */


  // Llamar cada vez que se cargue una página detectada con turbo:load
  // Tal vez en cache por lo que podría no haberse ejecutado iniciar 
  // nuevamente.
  // Podría ser llamada varias veces consecutivas por lo que debe detectarlo
  // para no ejecutar dos veces lo que no conviene.
  static ejecutarAlCargarPagina() {
    console.log("* Corriendo Jos19__Motor::ejecutarAlCargarPagina()")
  }

}
