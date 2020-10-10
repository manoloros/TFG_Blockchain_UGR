pragma solidity 0.6.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./Almacenes.sol";
import "./ComunidadesAutonomas.sol";
import "./SuministrosMedicos.sol";
import "./TrazabilidadSuministros.sol";
import "./Privado.sol";

/**
    @title Contrato que simplifica el acceso a la blockchain
    @author Manuel Ros Rodriguez
    @notice Facilita el acceso a las funcionalidades, gestionando la comunicacion
            con el resto de contratos
*/
contract AccesoBlockchain is Privado {

    Almacenes private contratoAlmacenes;
    ComunidadesAutonomas private contratoComunidades;
    SuministrosMedicos private contratoSuministros;
    TrazabilidadSuministros private contratoTrazabilidad;
    address[] private administradores;

    /**
        @notice Guarda en la lista de cuentas administrador a la cuenta que subio el contrato (cuenta autorizada)
    */
    constructor() public {
        administradores.push(msg.sender);
    }

    /**
        @notice Cambia el contrato Almacenes con el que se comunica este contrato
        @param direccionAlmacenes La direccion del nuevo contrato Almacenes
    */
    function cambiarContratoAlmacenes(Almacenes direccionAlmacenes) external soloCuentaAutorizada soloParado {
        contratoAlmacenes = direccionAlmacenes;
    }

    /**
        @notice Cambia el contrato ComunidadesAutonomas con el que se comunica este contrato
        @param direccionComunidades La direccion del nuevo contrato ComunidadesAutonomas
    */
    function cambiarContratoComunidades(ComunidadesAutonomas direccionComunidades) external soloCuentaAutorizada soloParado {
        contratoComunidades = direccionComunidades;
    }

    /**
        @notice Cambia el contrato SuministrosMedicos con el que se comunica este contrato
        @param direccionSuministros La direccion del nuevo contrato SuministrosMedicos
    */
    function cambiarContratoSuministros(SuministrosMedicos direccionSuministros) external soloCuentaAutorizada soloParado {
        contratoSuministros = direccionSuministros;
    }

    /**
        @notice Cambia el contrato TrazabilidadSuministros con el que se comunica este contrato
        @param direccionTrazabilidad La direccion del nuevo contrato TrazabilidadSuministros
    */
    function cambiarContratoTrazabilidad(TrazabilidadSuministros direccionTrazabilidad) external soloCuentaAutorizada soloParado {
        contratoTrazabilidad = direccionTrazabilidad;
    }

    /**
        @notice Inicializa el contrato, asignandole las direcciones de los contratos con los que interactuara
        @param direccionAlmacenes La direccion del contrato Almacenes
        @param direccionComunidades La direccion del contrato ComunidadesAutonomas
        @param direccionSuministros La direccion del contrato SuministrosMedicos
        @param direccionTrazabilidad La direccion del contrato TrazabilidadSuministros
    */
    function inicializar(Almacenes direccionAlmacenes, ComunidadesAutonomas direccionComunidades,
        SuministrosMedicos direccionSuministros, TrazabilidadSuministros direccionTrazabilidad) external soloCuentaAutorizada soloParado
    {
            contratoAlmacenes = direccionAlmacenes;
            contratoComunidades = direccionComunidades;
            contratoSuministros = direccionSuministros;
            contratoTrazabilidad = direccionTrazabilidad;
    }

    /**
        @notice Comprueba si el administrador indicado esta incluido en el sistema
        @param direccionAdministrador La direccion de la cuenta administrador
        @return si pertenece o no mediante un bool
    */
    function perteneceAdministrador(address direccionAdministrador) private view soloCuentaAutorizada puedeParar returns (bool) {
        bool pertenece = false;

        for (uint i=0; i<administradores.length && !pertenece; i++)
            if (administradores[i] == direccionAdministrador)
                pertenece = true;

        return pertenece;
    }

    /**
        @notice Anade una cuenta administrador nueva al sistema
        @param nuevoAdministrador La direccion de la cuenta administrador
    */
    function anadirAdministrador(address nuevoAdministrador) external soloCuentaAutorizada puedeParar {
        require(!perteneceAdministrador(nuevoAdministrador), "Error 400: Administrador ya incluido");
        administradores.push(nuevoAdministrador);
    }


    /**
        @notice Devuelve contenido JSON con todas las cuentas administrador que hay
        @return un JSON (string con contenido JSON) con todas las cuentas administrador que hay
                y con el siguiente formato:
                {
                    "resultado":["<administrador1>", "<administrador2>", ...]
                }
    */
    function getAdministradores() external view returns (string memory) {
        string memory administradoresJSON = '{"resultado":[';

        for (uint i=0; i<administradores.length; i++)
            if (i != (administradores.length-1))
                administradoresJSON = string(abi.encodePacked(administradoresJSON,'"',direccionAString(administradores[i]),'",'));
            else
                administradoresJSON = string(abi.encodePacked(administradoresJSON,'"',direccionAString(administradores[i]),'"'));

        administradoresJSON = string(abi.encodePacked(administradoresJSON,']}'));

        return (administradoresJSON);
    }

    /**
        @notice Devuelve contenido JSON con todos los identificadores de las comunidades autonomas que hay en el sistema
        @return un JSON (string con contenido JSON) con todos los identificadores de las comunidades autonomas
                que hay en el sistema y con el siguiente formato:
                {
                    "resultado":["<comunidad1>", "<comunidad2>", ...]
                }
    */
    function getComunidadesAutonomas() external view puedeParar returns (string memory) {
        return (contratoComunidades.getComunidadesAutonomas());
    }

    /**
        @notice Devuelve contenido JSON con toda la informacion de la comunidad autonoma indicada
        @param nombre Nombre de la comunidad autonoma (su identificador)
        @return un JSON (string con contenido JSON) con toda la informacion de la
                comunidad autonoma indicada y con el siguiente formato:
                {
                    "nombre":"<nombre>",
                    "informacion":"<informacion>",
                    "poblacion":<poblacion>,
                    "distritos":["<direccion1>","<direccion2>", ...],
                    "tiposSuministro":{
                        "<tipo1>":<unidades1>,
                        "<tipo2>":<unidades2>,
                        ...
                    }
                }
    */
    function getInformacionComunidad(string calldata nombre) external view puedeParar returns (string memory) {
        require(bytes(nombre).length != 0, "Error 400: String vacio");
        return (contratoComunidades.getInformacionComunidad(nombre));
    }

    /**
        @notice Anade una nueva comunidad autonoma al sistema
        @param nombre Nombre de la comunidad autonoma (su identificador)
        @param informacion Informacion de la comunidad autonoma
    */
    function anadirComunidadAutonoma(string calldata nombre, string calldata informacion) external soloCuentaAutorizada puedeParar {
        require(bytes(nombre).length != 0, "Error 400: String vacio");
        contratoComunidades.anadirComunidadAutonoma(nombre, informacion);
    }

    /**
        @notice Devuelve contenido JSON con todos los identificadores de los almacenes que hay en el sistema
        @return un JSON (string con contenido JSON) con todos los identificadores de los almacenes
                que hay en el sistema y con el siguiente formato:
                {
                    "resultado":["<almacen1>", "<almacen2>", ...]
                }
    */
    function getAlmacenes() external view puedeParar returns (string memory) {
        return (contratoAlmacenes.getAlmacenes());
    }

    /**
        @notice Devuelve contenido JSON con toda la informacion del almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @return un JSON (string con contenido JSON) con toda la informacion
                del almacen indicado y con el siguiente formato:
                {
                    "direccion":"<direccion>",
                    "comunidad":"<nombre>",
                    "informacion":"<nombre>",
                    "esDistrito":<bool>,
                    "poblacion":<poblacion>, (si es un distrito sanitario)
                    "suministros":[<idSuministro1>,<idSuministro2>, ...],
                    "tiposSuministro":{
                        "<tipo1>":<unidades1>,
                        "<tipo2>":<unidades2>,
                        ...
                    }
                }
    */
    function getInformacionAlmacen(address direccionAlmacen) external view puedeParar returns (string memory) {
        return (contratoAlmacenes.getInformacionAlmacen(direccionAlmacen));
    }

    /**
        @notice Devuelve contenido JSON con las unidades en total que tiene el almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @return un JSON (string con contenido JSON) con las unidades en total que tiene
                el almacen indicado y con el siguiente formato:
                {
                    "resultado":<unidades>
                }
    */
    function getUnidadesAlmacen(address direccionAlmacen) external view puedeParar returns (string memory) {
        uint unidades = contratoAlmacenes.getUnidadesAlmacen(direccionAlmacen);
        string memory resultado = string(abi.encodePacked('{"resultado":',Strings.toString(unidades),'}'));
        return (resultado);
    }

    /**
        @notice Devuelve contenido JSON con las unidades por tipo de suministro que tiene el
                almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @return un JSON (string con contenido JSON) con las unidades por tipo de
                suministro que tiene el almacen indicado y con el siguiente formato:
                {
                    "<tipo1>":<unidades1>,
                    "<tipo2>":<unidades2>,
                    ...
                }
    */
    function getUnidadesTiposAlmacen(address direccionAlmacen) external view puedeParar returns (string memory) {
        return (contratoAlmacenes.getUnidadesTiposAlmacen(direccionAlmacen));
    }

    /**
        @notice Devuelve contenido JSON con las unidades de un tipo de suministro especifico que
                tiene el almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @param tipoSuministro El tipo de suministro
        @return un JSON (string con contenido JSON) con las unidades de un tipo de
                suministro especifico que tiene el almacen indicado y con el siguiente formato:
                {
                    "resultado":<unidades>
                }
    */
    function getUnidadTipoAlmacen(address direccionAlmacen, string calldata tipoSuministro) external view puedeParar returns (string memory) {
        require(bytes(tipoSuministro).length != 0, "Error 400: String vacio");

        uint unidades = contratoAlmacenes.getUnidadTipoAlmacen(direccionAlmacen, tipoSuministro);
        string memory resultado = string(abi.encodePacked('{"resultado":',Strings.toString(unidades),'}'));

        return (resultado);
    }

    /**
        @notice Anade un nuevo almacen (que es tambien una cuenta de tipo almacen) al sistema
        @param direccionAlmacen Direccion (identificador) del almacen
        @param comunidad El nombre (identificador) de la comunidad autonoma a la que pertenece
        @param informacion Informacion del almacen
        @param esDistritoSanitario Nos indica si el almacen es ademas un distrito sanitario
        @param poblacion La poblacion del distrito sanitario (solo si es un distrito sanitario)
    */
    function anadirAlmacen(address direccionAlmacen, string calldata comunidad, string calldata informacion,
         bool esDistritoSanitario, uint poblacion) external soloCuentaAutorizada puedeParar {
        require(bytes(comunidad).length != 0 && bytes(informacion).length != 0, "Error 400: String vacio");
        contratoAlmacenes.anadirAlmacen(direccionAlmacen, comunidad, informacion, esDistritoSanitario, poblacion);
    }

    /**
        @notice Devuelve contenido JSON con todos los tipos de suministros que hay en el sistema
        @return un JSON (string con contenido JSON) con todos los tipos de suministros
                que hay en el sistema y con el siguiente formato:
                {
                    "resultado":["<tipo1>", "<tipo2>", ...]
                }
    */
    function getTiposSuministro() external view puedeParar returns (string memory) {
        return (contratoSuministros.getTiposSuministro());
    }

    /**
        @notice Devuelve contenido JSON indicando si el tipo de suministro especifico esta incluido
                en el sistema.
        @param tipoSuministro El tipo de suministro
        @return un JSON (string con contenido JSON) que indica si el tipo de suministro
                especifico esta incluido en el sistema. Tiene el siguiente formato:
                {
                    "resultado":<bool>
                }
    */
    function perteneceTipoSuministro(string calldata tipoSuministro) external view puedeParar returns (string memory) {
        require(bytes(tipoSuministro).length != 0, "Error 400: String vacio");

        bool pertenece = contratoSuministros.perteneceTipoSuministro(tipoSuministro);

        string memory resultado;

        if (pertenece)
            resultado = string(abi.encodePacked('{"resultado":true}'));
        else
            resultado = string(abi.encodePacked('{"resultado":false}'));

        return (resultado);
    }

    /**
        @notice Anade un nuevo tipo de suministro al sistema
        @param tipo El tipo de suministro
    */
    function anadirTipoSuministro(string calldata tipo) external soloCuentaAutorizada puedeParar {
        require(bytes(tipo).length != 0, "Error 400: String vacio");
        contratoSuministros.anadirTipoSuministro(tipo);
    }

    /**
        @notice Devuelve contenido JSON con todos los identificadores de los suministros que hay
                en el sistema
        @return un JSON (string con contenido JSON) con todos los identificadores de los
                suministros que hay en el sistema y con el siguiente formato:
                {
                    "resultado":[<idSuministro1>, <idSuministro2>, ...]
                }
    */
    function getSuministros() external view puedeParar returns (string memory) {
        return (contratoSuministros.getSuministros());
    }

    /**
        @notice Devuelve contenido JSON con toda la informacion del suministro indicado
        @param idSuministro Identificador del suministro
        @return un JSON (string con contenido JSON) con toda la informacion del
                suministro indicado y con el siguiente formato:
                {
                    "id":<idSuministro>,
                    "tipo":"<tipoSuministro>",
                    "tamano":<tamano>,
                    "almacenActual":"<almacen>",
                    "comunidadAsignada":"<nombre>",
                    "distritoDestino":"<distrito>",
                    "enViaje":<bool>,
                    "utilizado":<bool>
                }
    */
    function getInformacionSuministro(uint idSuministro) external view puedeParar returns (string memory) {
        return (contratoSuministros.getInformacionSuministro(idSuministro));
    }

    /**
        @notice Devuelve contenido JSON con toda la trazabilidad del suministro indicado
        @param idSuministro Identificador del suministro
        @return un JSON (string con contenido JSON) con toda la trazabilidad del
                suministro indicado y con el siguiente formato:
                {
                    "resultado":[{"almacenOrigen":"<direccion1>", "almacenDestino":"<direccion2>",
                                    "fechaSalida":"<fecha1>", "fechaEntrada":"<fecha2>"},
                                {"almacenOrigen":"<direccion1>", "almacenDestino":"<direccion2>",
                                    "fechaSalida":"<fecha1>", "fechaEntrada":"<fecha2>"},
                                 ...]
                }
    */
    function getTrazabilidadSuministro(uint idSuministro) external view puedeParar returns (string memory) {
        return (contratoTrazabilidad.getTrazabilidadSuministro(idSuministro));
    }

    /**
        @notice Anade un nuevo suministro al sistema (El suministro acaba de llegar a Espana)
        @param almacenInicio Direccion (identificador) del almacen en el que se encuentra el
                suministro
        @param tipoSuministro El tipo de suministro que es
        @param tamanoSuministro La cantidad de unidades que incluye el suministro
        @param preasignado La comunidad autonoma a la que esta preasignada, puede estar vacio
                (y en este caso no tiene ninguna comunidad preasignada)
        @param fecha La fecha en la que llego al almacen almacenInicio
    */
    function registrarSuministro(address almacenInicio, string calldata tipoSuministro,
        uint tamanoSuministro, string calldata preasignado, uint fecha) external soloCuentaAutorizada puedeParar
    {
        require(bytes(tipoSuministro).length != 0, "Error 400: String vacio");
        contratoSuministros.registrarSuministro(almacenInicio, tipoSuministro, tamanoSuministro, preasignado, fecha);
    }

    /**
        @notice Gestiona la salida de un suministro de un almacen
        @param origen Direccion (identificador) del almacen del que ha salido
        @param idSuministro El identificador del suministro
        @param fecha La fecha en la que el suministro salio del almacen
    */
    function notificarSalidaAlmacen(address origen, uint idSuministro, uint fecha) external soloCuentaAutorizada puedeParar {
        contratoSuministros.notificarSalidaAlmacen(origen, idSuministro, fecha);
    }

    /**
        @notice Gestiona la llegada de un suministro a un almacen
        @param destino Direccion (identificador) del almacen al que ha llegado el suministro
        @param idSuministro El identificador del suministro (El suministro debe de haber notificado
                su salida previamente)
        @param fecha La fecha en la que el suministro llego al almacen
    */
    function notificarLlegadaAlmacen(address destino, uint idSuministro, uint fecha) external soloCuentaAutorizada puedeParar {
        contratoSuministros.notificarLlegadaAlmacen(destino, idSuministro, fecha);
    }

    /**
        @notice Gestiona la apertura de un suministro
        @param direccionAlmacen Direccion (identificador) del almacen en el que se encuentra
                el suministro (Si este almacen no es el distrito sanitario asignado al suministro
                se lanzara una excepcion)
        @param idSuministro El identificador del suministro
        @param fecha La fecha en la que el suministro se ha utilizado
    */
    function utilizarSuministro(address direccionAlmacen, uint idSuministro, uint fecha) external soloCuentaAutorizada puedeParar {
        contratoSuministros.utilizarSuministro(direccionAlmacen, idSuministro, fecha);
    }

    /**
        @notice Modifica la comunidad autonoma indicada
        @param nombre El nombre (identificador) de la comunidad autonoma
        @param informacion La informacion nueva que se le quiere asignar
    */
    function modificarComunidadAutonoma(string calldata nombre, string calldata informacion) external soloCuentaAutorizada puedeParar {
        contratoComunidades.modificarComunidadAutonoma(nombre, informacion);
    }

    /**
        @notice Modifica el almacen indicado
        @param direccionAlmacen La direccion (identificador) del almacen
        @param informacion La informacion nueva que se le quiere asignar (En el caso de
                estar vacio no se modificara la informacion del almacen)
        @param poblacion La poblacion nueva que se le quiere asignar. Solo si es un
                distrito sanitario y en el caso de tener valor -1 no se modificara la
                poblacion del distrito sanitario
    */
    function modificarAlmacen(address direccionAlmacen, string calldata informacion, int poblacion) external soloCuentaAutorizada puedeParar {
        contratoAlmacenes.modificarAlmacen(direccionAlmacen, informacion, poblacion);
    }

}
