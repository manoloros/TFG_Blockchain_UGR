// Autor: Manuel Ros Rodriguez

// Modulos y constantes
const Web3 = require('web3');
const { setupLoader } = require('@openzeppelin/contract-loader');
const fs = require('fs');
const url = require('url');
const hostname = '0.0.0.0';
const port = 80;
const express = require('express');
const app = express();

const net = require('net');
const web3 = new Web3('/Users/manolo/tfgugr/geth.ipc', net);

web3.eth.handleRevert = true;

const cuentaAutorizada = '0x2594A47C8704d2Cf3C1A06a7105A13c16932a0Fa';

const loader = setupLoader({ provider: web3 }).web3;
const direccionAccesoBlockchain = '0xB29eaA341A97fb2567cd1640eDed8edc3eA0f45e';
const AccesoBlockchain = loader.fromArtifact('AccesoBlockchain', direccionAccesoBlockchain);

/**
 * Los tipos de cuentas que existen en el sistema
 * @enum
 */
const rolUsuario = {
    ADMINISTRADOR: 1,
    ALMACEN: 2,
};
Object.freeze(rolUsuario);


app.use(express.urlencoded({extended: true}));

// Funciones

/**
 * Inicia sesion en la cuenta del usuario utilizando los mecanismos dados por Ethereum,
 * para facilitar la lectura el proceso se divide en tres funciones, la funcion actual,
 * comprobarAdministradores y comprobarAlmacenes.
 *
 * @param usuario - La direccion (nombre de usuario) de la cuenta
 * @param password - La contrasena de la cuenta
 * @param rolOperacion - El tipo de cuenta que se necesita para poder ejecutar
 *      la operacion
 * @param operacion - La funcion que se quiere ejecutar
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function autentificarUsuario(usuario, password, rolOperacion, operacion, req, res){
    if (comprobarDireccion(usuario, res))
    	web3.eth.personal.unlockAccount(usuario, password, 600, function(err, data) {
    		if (err)
    			procesarErrorPeticion(err, res);
    		else
    			comprobarAdministradores(usuario, rolOperacion, operacion, req, res);
    	});
}

/**
 * Si se llama a esta funcion es que se ha conseguido iniciar sesion y ahora se
 * comprobara el tipo de cuenta en la que se ha iniciado sesion, mas especificamente
 * en esta funcion se comprueba si es una cuenta tipo administrador y si lo es
 * y la operacion es ejecutable por un administrador, se ejecutara la operacion
 *
 * @param usuario - La direccion (nombre de usuario) de la cuenta
 * @param rolOperacion - El tipo de cuenta que se necesita para poder ejecutar
 *      la operacion
 * @param operacion - La funcion que se quiere ejecutar
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function comprobarAdministradores(usuario, rolOperacion, operacion, req, res) {
	AccesoBlockchain.methods.getAdministradores()
	.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
		if (err) {
			procesarErrorPeticion(err, res);
		} else {
			var respuestaJSON = JSON.parse(data);

			if (respuestaJSON.resultado.includes(usuario))
				if (rolOperacion === rolUsuario.ADMINISTRADOR)
					operacion(req, res);
				else
					responderPeticion(null, 403, res);
			else
				comprobarAlmacenes(usuario, rolOperacion, operacion, req, res);
		}
	});
}

/**
 * Si se llama a esta funcion es que se ha conseguido iniciar sesion y la cuenta
 * no es de tipo administrador, por lo que comprobaremos si es de tipo almacen
 * y si lo es y la operacion es ejecutable por un almacen, se ejecutara
 * la operacion
 *
 * @param usuario - La direccion (nombre de usuario) de la cuenta
 * @param rolOperacion - El tipo de cuenta que se necesita para poder ejecutar
 *      la operacion
 * @param operacion - La funcion que se quiere ejecutar
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function comprobarAlmacenes(usuario, rolOperacion, operacion, req, res) {
	AccesoBlockchain.methods.getAlmacenes()
	.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
		if (err) {
			procesarErrorPeticion(err, res);
		} else {
			var respuestaJSON = JSON.parse(data);

			if (respuestaJSON.resultado.includes(usuario))
				if (rolOperacion === rolUsuario.ALMACEN)
					operacion(req, res);
				else
					responderPeticion(null, 403, res);
			else
				responderPeticion(null, 401, res);
		}
	});
}

/**
 * Se llama cuando ocurre un error desconocido y que se encarga
 * de comprobar cual es el error y dar la respuesta adecuada
 *
 * @param err - El error que nos ha devuelto la funcion ejecutada
 * @param res - El objeto respuesta (response) que nos da Express
 */
function procesarErrorPeticion(err, res) {

    var error;
    if (err.reason != null)
        error = err.reason;
    else if (err.receipt != null)
        error = err.receipt;
    else
        error = err.toString();

	if (error.includes('404'))
		responderPeticion('{"error":"'+error+'"}', 404, res);
	else if (error.includes('400'))
		responderPeticion('{"error":"'+error+'"}', 400, res);
	else if (error.includes('could not decrypt'))
		responderPeticion(null, 401, res);
	else
		responderPeticion('{"error":"'+error+'"}', 500, res);
}

/**
 * Envia una respueta a la peticion HTTP recibida, si no queremos
 * enviar contenido JSON le daremos el valor null al parametro
 * contenido
 *
 * @param contenido - El contenido JSON que se va a enviar
 * @param estado - El estado que tendra la respuesta
 * @param res - El objeto respuesta (response) que nos da Express
 */
function responderPeticion(contenido, estado, res) {
	if (contenido) {
		res.writeHead(estado, {'Content-Type': 'application/json'});
		res.write(contenido);
	} else
		res.writeHead(estado);

	res.end();
}

/**
 * Comprueba que la direccion sea valida, en caso de no ser valida
 * responde a la peticion HTTP indicando esto mismo y devuelve un
 * valor false. En caso de si ser valida no responde a la peticion
 * y devuelve un valor true.
 *
 * @param direccion - La direccion que se quiere comprobar
 * @param res - El objeto respuesta (response) que nos da Express
 */
function comprobarDireccion(direccion, res) {
	if (!web3.utils.isAddress(direccion)) {
		responderPeticion('{"error":"Direccion no valida"}', 400, res);
		return false;
	} else
		return true;
}

/**
 * Comprueba que el numero sea valido, en caso de no ser valido
 * responde a la peticion HTTP indicando esto mismo y devuelve un
 * valor false. En caso de si ser valida no responde a la peticion
 * y devuelve un valor true.
 *
 * @param numero - El numero que se quiere comprobar
 * @param res - El objeto respuesta (response) que nos da Express
 */
function comprobarNumero(numero, res) {
	if (isNaN(numero)) {
		responderPeticion('{"error":"Identificador no es un numero"}', 400, res);
		return false;
	} else
		return true;
}

/**
 *
 * Para que se procesen algunas peticiones necesitaremos iniciar sesion
 * con una cuenta almacen o administrador dependiendo de la funcionalidad
 *
 * Para iniciar sesion incluimos dos variables con formato
 * x-www-form-urlencoded, usuario y password. La variable usuario es
 * la direccion de la cuenta ethereum utilizada, que cuando estamos hablando de
 * cuentas almacen es equivalente al identificador de un almacen,
 * para saber cual es el almacen que ha enviado la peticion y confirmar
 * que de verdad ha sido ese almacen
 *
 * La variable password es la contrasena de la cuenta
 *
 * Estas dos variables no se incluyen en los comentarios de cada peticion,
 * ya que siempre son las dos mismas variables
 *
 * En los comentarios de las peticiones indicamos si es necesario
 * iniciar sesion y que tipo de cuenta se necesita
 *
 */

/**
 * Peticion HTTP: GET /
 *
 * Devuelve el archivo index.html, que es la interfaz web basica
 * que interactua con la API REST creada
 *
 */
app.get('/', function (req, res) {
	fs.readFile('index.html', function(err, data) {
		res.writeHead(200, {'Content-Type': 'text/html'});
		res.write(data);
		res.end();
	});
});

/**
 * Peticion HTTP: GET /administradores
 *
 * Devuelve contenido JSON con todas las cuentas administrador que
 * hay y con el siguiente formato:
 * {
 *   "resultado":["<administrador1>", "<administrador2>", ...]
 * }
 *
 */
app.get('/administradores', function (req, res) {
	console.log('get /administradores');
	AccesoBlockchain.methods.getAdministradores()
	.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
		if (err)
			procesarErrorPeticion(err, res);
		else
			responderPeticion(data, 200, res);
	});
});

/**
 * Peticion HTTP: POST /administradores
 *
 * Anade una cuenta administrador nueva al sistema
 *
 * Requiere iniciar sesion con una cuenta administrador
 *
 * En la peticion se necesitan las siguientes variables con formato
 * x-www-form-urlencoded:
 *
 * @param nuevoAdministrador - La direccion de la cuenta administrador
 *
 */
app.post('/administradores', function (req, res) {
	console.log('post /administradores');
	autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ADMINISTRADOR, anadirAdministrador, req, res);
});

/**
 * Anade una cuenta administrador nueva al sistema
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function anadirAdministrador(req, res) {
	AccesoBlockchain.methods.anadirAdministrador(req.body.nuevoAdministrador)
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 201, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

/**
 * Peticion HTTP: GET /comunidades
 *
 * Devuelve contenido JSON con todos los identificadores de las comunidades
 * autonomas que hay en el sistema y con el siguiente formato:
 * {
 *      "resultado":["<comunidad1>", "<comunidad2>", ...]
 * }
 *
 */
app.get('/comunidades', function (req, res) {
	console.log('get /comunidades');
	AccesoBlockchain.methods.getComunidadesAutonomas()
	.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
		if (err)
			procesarErrorPeticion(err, res);
		else
			responderPeticion(data, 200, res);
	});
});

/**
 * Peticion HTTP: GET /comunidades/<nombre>
 *
 * Devuelve contenido JSON con toda la informacion de la comunidad autonoma
 * indicada y con el siguiente formato:
 * {
 *      "nombre":"<nombre>",
 *      "informacion":"<informacion>",
 *      "poblacion":<poblacion>,
 *      "distritos":["<direccion1>","<direccion2>", ...],
 *      "tiposSuministro":{
 *          "<tipo1>":<unidades1>,
 *          "<tipo2>":<unidades2>,
 *          ...
 *      }
 * }
 *
 */
app.get('/comunidades/:nombre', function (req, res) {
	console.log('get /comunidades/'+req.params.nombre.toLowerCase());
	AccesoBlockchain.methods.getInformacionComunidad(req.params.nombre.toLowerCase())
	.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
		if (err)
			procesarErrorPeticion(err, res);
		else
			responderPeticion(data, 200, res);
	});
});

/**
 * Peticion HTTP: PUT /comunidades/<nombre>
 *
 * Modifica la comunidad autonoma indicada
 *
 * Requiere iniciar sesion con una cuenta administrador
 *
 * En la peticion se necesitan las siguientes variables con formato
 * x-www-form-urlencoded:
 *
 * @param informacion - La informacion nueva que se le quiere asignar
 *
 */
app.put('/comunidades/:nombre', function (req, res) {
	console.log('put /comunidades/'+req.params.nombre.toLowerCase());
	autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ADMINISTRADOR, modificarComunidadAutonoma, req, res);
});

/**
 * Modifica la comunidad autonoma indicada
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function modificarComunidadAutonoma(req, res) {
	AccesoBlockchain.methods.modificarComunidadAutonoma(req.params.nombre.toLowerCase(), req.body.informacion)
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 204, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

/**
 * Peticion HTTP: POST /comunidades
 *
 * Anade una nueva comunidad autonoma al sistema
 *
 * Requiere iniciar sesion con una cuenta administrador
 *
 * En la peticion se necesitan las siguientes variables con formato
 * x-www-form-urlencoded:
 *
 * @param nombre - Nombre de la comunidad autonoma (su identificador)
 * @param informacion - Informacion de la comunidad autonoma
 *
 */
app.post('/comunidades', function (req, res) {
	console.log('post /comunidades');
	autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ADMINISTRADOR, anadirComunidadAutonoma, req, res);
});

/**
 * Anade una nueva comunidad autonoma al sistema
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function anadirComunidadAutonoma(req, res) {
	AccesoBlockchain.methods.anadirComunidadAutonoma(req.body.nombre.toLowerCase(), req.body.informacion)
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 201, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

/**
 * Peticion HTTP: GET /almacenes
 *
 * Devuelve contenido JSON con todos los identificadores de los
 * almacenes que hay en el sistema y con el siguiente formato:
 * {
 *      "resultado":["<almacen1>", "<almacen2>", ...]
 * }
 *
 */
app.get('/almacenes', function (req, res) {
	console.log('get /almacenes');
	AccesoBlockchain.methods.getAlmacenes()
	.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
		if (err)
			procesarErrorPeticion(err, res);
		else
			responderPeticion(data, 200, res);
	});
});

/**
 * Peticion HTTP: GET /almacenes/<direccionAlmacen>
 *
 * Devuelve contenido JSON con toda la informacion del almacen
 * indicado y con el siguiente formato:
 * {
 *      "direccion":"<direccion>",
 *      "comunidad":"<nombre>",
 *      "informacion":"<nombre>",
 *      "esDistrito":<bool>,
 *      "poblacion":<poblacion>, (si es un distrito sanitario)
 *      "suministros":[<idSuministro1>,<idSuministro2>, ...],
 *      "tiposSuministro":{
 *          "<tipo1>":<unidades1>,
 *          "<tipo2>":<unidades2>,
 *          ...
 *      }
 * }
 *
 */
app.get('/almacenes/:direccionAlmacen', function (req, res) {
	console.log('get /almacenes/'+req.params.direccionAlmacen);
	if (comprobarDireccion(req.params.direccionAlmacen, res))
		AccesoBlockchain.methods.getInformacionAlmacen(req.params.direccionAlmacen)
		.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
			if (err)
				procesarErrorPeticion(err, res);
			else
				responderPeticion(data, 200, res);
		});
});

/**
 * Peticion HTTP: PUT /almacenes/<direccionAlmacen>
 *
 * Modifica el almacen indicado
 *
 * Requiere iniciar sesion con una cuenta administrador
 *
 * En la peticion se necesitan las siguientes variables con formato
 * x-www-form-urlencoded:
 *
 * @param informacion - La informacion nueva que se le quiere asignar
 * (En el caso de estar vacio no se modificara la informacion del almacen)
 * @param poblacion - La poblacion nueva que se le quiere asignar.
 * Solo si es un distrito sanitario y en el caso de tener valor -1
 * no se modificara la poblacion del distrito sanitario
 *
 */
app.put('/almacenes/:direccionAlmacen', function (req, res) {
	console.log('put /almacenes/'+req.params.direccionAlmacen);
	autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ADMINISTRADOR, modificarAlmacen, req, res);
});

/**
 * Modifica el almacen indicado
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function modificarAlmacen(req, res) {
	AccesoBlockchain.methods.modificarAlmacen(req.params.direccionAlmacen, req.body.informacion,
		req.body.poblacion)
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 204, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

/**
 * Peticion HTTP: POST /almacenes
 *
 * Anade un nuevo almacen (que es tambien una cuenta de tipo almacen)
 * al sistema
 *
 * Requiere iniciar sesion con una cuenta administrador
 *
 * En la peticion se necesitan las siguientes variables con formato
 * x-www-form-urlencoded:
 *
 * @param direccionAlmacen - Direccion (identificador) del almacen
 * @param comunidad - El nombre (identificador) de la comunidad autonoma a la que pertenece
 * @param informacion - Informacion del almacen
 * @param esDistritoSanitario - Nos indica si el almacen es ademas un distrito sanitario
 * @param poblacion - La poblacion del distrito sanitario (solo si es un distrito sanitario)
 *
 */
app.post('/almacenes', function (req, res) {
	console.log('post /almacenes');
	if (comprobarDireccion(req.body.direccionAlmacen, res))
		autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ADMINISTRADOR, anadirAlmacen, req, res);
});

/**
 * Anade un nuevo almacen (que es tambien una cuenta de tipo almacen)
 * al sistema
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function anadirAlmacen(req, res) {
	AccesoBlockchain.methods.anadirAlmacen(req.body.direccionAlmacen, req.body.comunidad.toLowerCase(),
		req.body.informacion, req.body.esDistritoSanitario == 'true', req.body.poblacion)
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 201, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

/**
 * Peticion HTTP: GET /almacenes/<direccionAlmacen>/unidades
 *
 * Devuelve contenido JSON con las unidades en total que tiene el
 * almacen indicado y con el siguiente formato:
 * {
 *      "resultado":<unidades>
 * }
 *
 */
app.get('/almacenes/:direccionAlmacen/unidades', function (req, res) {
	console.log('get /almacenes/'+req.params.direccionAlmacen+'/unidades');
	if (comprobarDireccion(req.params.direccionAlmacen, res))
		AccesoBlockchain.methods.getUnidadesAlmacen(req.params.direccionAlmacen)
		.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
			if (err)
				procesarErrorPeticion(err, res);
			else
				responderPeticion(data, 200, res);
		});
});

/**
 * Peticion HTTP: GET /almacenes/<direccionAlmacen>/unidades-por-tipo
 *
 * Devuelve contenido JSON con las unidades por tipo de suministro
 * que tiene el almacen indicado y con el siguiente formato:
 * {
 *      "<tipo1>":<unidades1>,
 *      "<tipo2>":<unidades2>,
 *      ...
 * }
 *
 */
app.get('/almacenes/:direccionAlmacen/unidades-por-tipo', function (req, res) {
	console.log('get /almacenes/'+req.params.direccionAlmacen+'/unidades-por-tipo');
	if (comprobarDireccion(req.params.direccionAlmacen, res))
		AccesoBlockchain.methods.getUnidadesTiposAlmacen(req.params.direccionAlmacen)
		.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
			if (err)
				procesarErrorPeticion(err, res);
			else
				responderPeticion(data, 200, res);
		});
});

/**
 * Peticion HTTP: GET /almacenes/<direccionAlmacen>/unidades/<tipoSuministro>
 *
 * Devuelve contenido JSON con las unidades de un tipo de suministro
 * especifico que tiene el almacen indicado y con el siguiente formato:
 * {
 *      "resultado":<unidades>
 * }
 *
 */
app.get('/almacenes/:direccionAlmacen/unidades/:tipoSuministro', function (req, res) {
	console.log('get /almacenes/'+req.params.direccionAlmacen+'/unidades/'+req.params.tipoSuministro.toLowerCase());
	if (comprobarDireccion(req.params.direccionAlmacen, res))
		AccesoBlockchain.methods.getUnidadTipoAlmacen(req.params.direccionAlmacen, req.params.tipoSuministro.toLowerCase())
		.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
			if (err)
				procesarErrorPeticion(err, res);
			else
				responderPeticion(data, 200, res);
		});
});

/**
 * Peticion HTTP: GET /tipos-suministro
 *
 * Devuelve contenido JSON con todos los tipos de suministros que
 * hay en el sistema y con el siguiente formato:
 * {
 *      "resultado":["<tipo1>", "<tipo2>", ...]
 * }
 *
 */
app.get('/tipos-suministro', function (req, res) {
	console.log('get /tipos-suministro');
	AccesoBlockchain.methods.getTiposSuministro()
	.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
		if (err)
			procesarErrorPeticion(err, res);
		else
			responderPeticion(data, 200, res);
	});
});

/**
 * Peticion HTTP: GET /tipos-suministro/<tipoSuministro>
 *
 * Comprueba si el tipo de suministro indicado existe en el
 * sistema. No devuelve contenido JSON.
 *
 */
app.get('/tipos-suministro/:tipoSuministro', function (req, res) {
	console.log('get /tipos-suministro/'+req.params.tipoSuministro.toLowerCase());
	AccesoBlockchain.methods.perteneceTipoSuministro(req.params.tipoSuministro.toLowerCase())
	.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
		if (err)
			procesarErrorPeticion(err, res);
		else {
			var respuestaJSON = JSON.parse(data);

			if (respuestaJSON.resultado)
				responderPeticion(null, 204, res);
			else
				responderPeticion(null, 404, res);
		}
	});
});

/**
 * Peticion HTTP: POST /tipos-suministro
 *
 * Anade un nuevo tipo de suministro al sistema
 *
 * Requiere iniciar sesion con una cuenta administrador
 *
 * En la peticion se necesitan las siguientes variables con formato
 * x-www-form-urlencoded:
 *
 * @param tipo - El tipo de suministro
 *
 */
app.post('/tipos-suministro', function (req, res) {
	console.log('post /tipos-suministro');
	autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ADMINISTRADOR, anadirTipoSuministro, req, res);
});

/**
 * Anade un nuevo tipo de suministro al sistema
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function anadirTipoSuministro(req, res) {
	AccesoBlockchain.methods.anadirTipoSuministro(req.body.tipo.toLowerCase())
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 201, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

/**
 * Peticion HTTP: GET /suministros
 *
 * Devuelve contenido JSON con todos los identificadores de los
 * suministros que hay en el sistema y con el siguiente formato:
 * {
 *      "resultado":[<idSuministro1>, <idSuministro2>, ...]
 * }
 *
 */
app.get('/suministros', function (req, res) {
	console.log('get /suministros');
	AccesoBlockchain.methods.getSuministros()
	.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
		if (err)
			procesarErrorPeticion(err, res);
		else
			responderPeticion(data, 200, res);
	});
});

/**
 * Peticion HTTP: GET /suministros/<idSuministro>
 *
 * Devuelve contenido JSON con toda la informacion del suministro
 * indicado y con el siguiente formato:
 * {
 *      "id":<idSuministro>,
 *      "tipo":"<tipoSuministro>",
 *      "tamano":<tamano>,
 *      "almacenActual":"<almacen>",
 *      "comunidadAsignada":"<nombre>",
 *      "distritoDestino":"<distrito>",
 *      "enViaje":<bool>,
 *      "utilizado":<bool>
 * }
 *
 */
app.get('/suministros/:idSuministro', function (req, res) {
	console.log('get /suministros/'+req.params.idSuministro);
	if (comprobarNumero(req.params.idSuministro, res))
		AccesoBlockchain.methods.getInformacionSuministro(req.params.idSuministro)
		.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
			if (err)
				procesarErrorPeticion(err, res);
			else
				responderPeticion(data, 200, res);
		});
});

/**
 * Peticion HTTP: GET /suministros/<idSuministro>/trazabilidad
 *
 * Devuelve contenido JSON con toda la trazabilidad del suministro
 * indicado y con el siguiente formato:
 * {
 *      "resultado":[{"almacenOrigen":"<direccion1>", "almacenDestino":"<direccion2>",
 *                      "fechaSalida":"<fecha1>", "fechaEntrada":"<fecha2>"},
 *                  {"almacenOrigen":"<direccion1>", "almacenDestino":"<direccion2>",
 *                      "fechaSalida":"<fecha1>", "fechaEntrada":"<fecha2>"},
 *                   ...]
 * }
 *
 */
app.get('/suministros/:idSuministro/trazabilidad', function (req, res) {
	console.log('get /suministros/'+req.params.idSuministro+'/trazabilidad');
	if (comprobarNumero(req.params.idSuministro, res))
		AccesoBlockchain.methods.getTrazabilidadSuministro(req.params.idSuministro)
		.call({ from: cuentaAutorizada, gas:1000000 }, function(err, data) {
			if (err)
				procesarErrorPeticion(err, res);
			else
				responderPeticion(data, 200, res);
		});
});

/**
 * Peticion HTTP: POST /suministros
 *
 * Anade un nuevo suministro al sistema (El suministro acaba de
 * llegar a Espana)
 *
 * Requiere iniciar sesion con una cuenta almacen
 *
 * En la peticion se necesitan las siguientes variables con formato
 * x-www-form-urlencoded:
 *
 * @param tipoSuministro - El tipo de suministro que es
 * @param tamanoSuministro - La cantidad de unidades que incluye el suministro
 * @param preasignado - La comunidad autonoma a la que esta preasignada,
 * puede estar vacio (y en este caso no tiene ninguna comunidad preasignada)
 * @param fecha - La fecha en la que llego al almacen almacenInicio
 *
 */
app.post('/suministros', function (req, res) {
	console.log('post /suministros');
	if (comprobarDireccion(req.body.usuario.toLowerCase(), res))
		autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ALMACEN, registrarSuministro, req, res);
});

/**
 * Anade un nuevo suministro al sistema (El suministro acaba de
 * llegar a Espana)
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 */
function registrarSuministro(req, res) {
	AccesoBlockchain.methods.registrarSuministro(req.body.usuario.toLowerCase(), req.body.tipoSuministro.toLowerCase(),
		req.body.tamanoSuministro, req.body.preasignado, req.body.fecha)
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 201, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

/**
 * Peticion HTTP: POST /suministros/<idSuministro>/trazabilidad
 *
 * Gestiona la trazabilidad de los suministros, dependiendo del valor
 * de la variable tipo se ejecutara una funcion u otra
 *
 * Requiere iniciar sesion con una cuenta almacen
 *
 * En la peticion se necesitan las siguientes variables con formato
 * x-www-form-urlencoded:
 *
 * @param tipo - El tipo de operacion de trazabilidad que se va a realizar,
 * puede ser de tipo salida, llegada o utilizar
 * @param idSuministro - El identificador del suministro
 * @param fecha - La fecha en la que ocurrio el evento
 *
 */
app.post('/suministros/:idSuministro/trazabilidad', function (req, res) {
	console.log('post /suministros/'+req.params.idSuministro+'/trazabilidad');

	if (comprobarDireccion(req.body.usuario.toLowerCase(), res) && comprobarNumero(req.params.idSuministro, res))
		if (req.body.tipo.toLowerCase() === 'llegada')
			autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ALMACEN, notificarLlegadaAlmacen, req, res);
		else if (req.body.tipo.toLowerCase() === 'salida')
			autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ALMACEN, notificarSalidaAlmacen, req, res);
		else if (req.body.tipo.toLowerCase() === 'utilizar')
			autentificarUsuario(req.body.usuario.toLowerCase(), req.body.password, rolUsuario.ALMACEN, utilizarSuministro, req, res);
		else
			responderPeticion('{"error":"Tipo de operacion de trazabilidad no existe"}', 400, res);
});

/**
 * Gestiona la salida de un suministro de un almacen
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 *
 */
function notificarSalidaAlmacen(req, res) {
	AccesoBlockchain.methods.notificarSalidaAlmacen(req.body.usuario.toLowerCase(), req.params.idSuministro,
		req.body.fecha)
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 201, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

/**
 * Gestiona la llegada de un suministro a un almacen
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 *
 */
function notificarLlegadaAlmacen(req, res) {
	AccesoBlockchain.methods.notificarLlegadaAlmacen(req.body.usuario.toLowerCase(), req.params.idSuministro,
		req.body.fecha)
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 201, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

/**
 * Gestiona la apertura de un suministro
 *
 * @param req - El objeto solicitud (request) que nos da Express
 * @param res - El objeto respuesta (response) que nos da Express
 *
 */
function utilizarSuministro(req, res) {
	AccesoBlockchain.methods.utilizarSuministro(req.body.usuario.toLowerCase(), req.params.idSuministro,
		req.body.fecha)
	.send({ from: cuentaAutorizada, gas:1000000 }).on('receipt', function() {
		responderPeticion(null, 201, res);
	}).on('error', function(err) {
		procesarErrorPeticion(err, res);
	});
}

// Iniciamos el servidor HTTP
app.listen(80);
