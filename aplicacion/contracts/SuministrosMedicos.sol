pragma solidity 0.6.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./Almacenes.sol";
import "./TrazabilidadSuministros.sol";
import "./AccesoBlockchain.sol";
import "./ComunidadesAutonomas.sol";
import "./Privado.sol";

/**
    @title Contrato que gestiona los suministros medicos
    @author Manuel Ros Rodriguez
    @notice Contrato que se encarga de gestionar la funcionalidad relacionada
            con los suministros medicos
*/
contract SuministrosMedicos is Privado {

    struct suministro {
        string tipo;
        uint tamano;
        address distritoDestino;
        bool utilizado;
    }

    uint[] private suministros;
    mapping(uint => suministro) private informacionSuministro;
    string[] private tiposSuministro;
    mapping(string => bool) private existeTipoSuministro;

    Almacenes private contratoAlmacenes;
    TrazabilidadSuministros private contratoTrazabilidad;
    ComunidadesAutonomas private contratoComunidades;
    AccesoBlockchain private contratoAcceso;


    /*
        modificador que utilizamos en los metodos para que el contrato solo acepte llamadas
        al metodo enviadas por los contratos que conoce
    */
    modifier soloContratos {
        require(msg.sender == address(contratoAlmacenes) ||
                msg.sender == address(contratoTrazabilidad) ||
                msg.sender == address(contratoComunidades) ||
                msg.sender == address(contratoAcceso), "Recibida llamada de contrato no autorizado");
        _;
    }

    /**
        @notice Cambia el contrato Almacenes con el que se comunica este contrato
        @param direccionAlmacenes La direccion del nuevo contrato Almacenes
    */
    function cambiarContratoAlmacenes(Almacenes direccionAlmacenes) external soloCuentaAutorizada soloParado {
        contratoAlmacenes = direccionAlmacenes;
    }

    /**
        @notice Cambia el contrato TrazabilidadSuministros con el que se comunica este contrato
        @param direccionTrazabilidad La direccion del nuevo contrato TrazabilidadSuministros
    */
    function cambiarContratoTrazabilidad(TrazabilidadSuministros direccionTrazabilidad) external soloCuentaAutorizada soloParado {
        contratoTrazabilidad = direccionTrazabilidad;
    }

    /**
        @notice Cambia el contrato ComunidadesAutonomas del que recibe llamadas
        @param direccionComunidades La direccion del nuevo contrato ComunidadesAutonomas
    */
    function cambiarContratoComunidades(ComunidadesAutonomas direccionComunidades) external soloCuentaAutorizada soloParado {
        contratoComunidades = direccionComunidades;
    }

    /**
        @notice Cambia el contrato AccesoBlockchain del que recibe llamadas
        @param direccionAcceso La direccion del nuevo contrato AccesoBlockchain
    */
    function cambiarContratoAcceso(AccesoBlockchain direccionAcceso) external soloCuentaAutorizada soloParado {
        contratoAcceso = direccionAcceso;
    }

    /**
        @notice Inicializa el contrato, asignandole las direcciones de los contratos con los que interactuara
        @param direccionAlmacenes La direccion del contrato Almacenes
        @param direccionTrazabilidad La direccion del contrato TrazabilidadSuministros
        @param direccionComunidades La direccion del contrato ComunidadesAutonomas
        @param direccionAcceso La direccion del contrato AccesoBlockchain
    */
    function inicializar(Almacenes direccionAlmacenes, TrazabilidadSuministros direccionTrazabilidad,
        ComunidadesAutonomas direccionComunidades, AccesoBlockchain direccionAcceso) external soloCuentaAutorizada soloParado
    {
        contratoAlmacenes = direccionAlmacenes;
        contratoTrazabilidad = direccionTrazabilidad;
        contratoComunidades = direccionComunidades;
        contratoAcceso = direccionAcceso;
    }

    /**
        @notice Anade un nuevo tipo de suministro al sistema
        @param tipo El tipo de suministro
    */
    function anadirTipoSuministro(string calldata tipo) external soloContratos puedeParar {
        require(!perteneceTipoSuministro(tipo), "Error 400: Tipo de suministro ya incluido");
        tiposSuministro.push(tipo);
        existeTipoSuministro[tipo] = true;
    }

    /**
        @notice Comprueba si el tipo de suministro indicado esta incluido en el sistema
        @param tipoSuministro El tipo de suministro
        @return si pertenece o no mediante un bool
    */
    function perteneceTipoSuministro(string calldata tipoSuministro) public view puedeParar returns (bool) {
        return (existeTipoSuministro[tipoSuministro]);
    }

    /**
        @notice Comprueba si el suministro indicado esta incluido en el sistema
        @param idSuministro El identificador del suministro
        @return si pertenece o no mediante un bool
    */
    function perteneceSuministro(uint idSuministro) public view puedeParar returns (bool) {
        if (bytes(informacionSuministro[idSuministro].tipo).length == 0)
            return false;
        else
            return true;
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
        string memory tipos = '{"resultado":[';

        for (uint i=0; i<tiposSuministro.length; i++)
            if (i != (tiposSuministro.length-1))
                tipos = string(abi.encodePacked(tipos,'"',tiposSuministro[i],'",'));
            else
                tipos = string(abi.encodePacked(tipos,'"',tiposSuministro[i],'"'));

        tipos = string(abi.encodePacked(tipos,']}'));

        return (tipos);
    }

    /**
        @notice Devuelve el numero de tipos de suministros que hay registrados en el sistema
        @return el numero de tipos de suministros que hay registrados en el sistema
    */
    function getTiposSuministroTamano() external view puedeParar returns (uint) {
        return (tiposSuministro.length);
    }

    /**
        @notice Devuelve el tipo de suministro que se encuentra en la posicion indicada del vector
        @param indice La posicion del vector
        @return el tipo de suministro que se encuentra en la posicion indicada del vector
    */
    function getTipoSuministroIndice(uint indice) external view puedeParar returns (string memory) {
        require(indice < tiposSuministro.length, "Indice fuera del rango del array");
        return (tiposSuministro[indice]);
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
        uint tamanoSuministro, string calldata preasignado, uint fecha) external
        soloContratos puedeParar
    {
        require(perteneceTipoSuministro(tipoSuministro), "Error 400: Tipo de suministro no encontrado");

        uint idSuministro = suministros.length;

        contratoTrazabilidad.registrarSuministro(idSuministro, almacenInicio, fecha);
        address distrito = contratoAlmacenes.registrarSuministro(almacenInicio, idSuministro, tipoSuministro, tamanoSuministro, preasignado);

        suministros.push(idSuministro);
        informacionSuministro[idSuministro] = suministro(tipoSuministro, tamanoSuministro, distrito, false);
    }

    /**
        @notice Gestiona la salida de un suministro de un almacen
        @param origen Direccion (identificador) del almacen del que ha salido
        @param idSuministro El identificador del suministro
        @param fecha La fecha en la que el suministro salio del almacen
    */
    function notificarSalidaAlmacen(address origen, uint idSuministro, uint fecha) external soloContratos puedeParar {
        require(perteneceSuministro(idSuministro), "Error 404: Suministro no encontrado");
        require(informacionSuministro[idSuministro].utilizado != true, "Error 400: Suministro ha sido utilizado");

        string memory tipoSuministro = informacionSuministro[idSuministro].tipo;
        uint tamanoSuministro = informacionSuministro[idSuministro].tamano;

        contratoAlmacenes.notificarSalidaAlmacen(origen, idSuministro, tipoSuministro, tamanoSuministro);
        contratoTrazabilidad.notificarSalidaAlmacen(origen, idSuministro, fecha);
    }

    /**
        @notice Gestiona la llegada de un suministro a un almacen
        @param destino Direccion (identificador) del almacen al que ha llegado el suministro
        @param idSuministro El identificador del suministro (El suministro debe de haber notificado
                su salida previamente)
        @param fecha La fecha en la que el suministro llego al almacen
    */
    function notificarLlegadaAlmacen(address destino, uint idSuministro, uint fecha) external soloContratos puedeParar {
        require(perteneceSuministro(idSuministro), "Error 404: Suministro no encontrado");

        string memory tipoSuministro = informacionSuministro[idSuministro].tipo;
        uint tamanoSuministro = informacionSuministro[idSuministro].tamano;

        contratoAlmacenes.notificarLlegadaAlmacen(destino, idSuministro, tipoSuministro, tamanoSuministro);
        contratoTrazabilidad.notificarLlegadaAlmacen(destino, idSuministro, fecha);
    }

    /**
        @notice Gestiona la apertura de un suministro
        @param direccionAlmacen Direccion (identificador) del almacen en el que se encuentra
                el suministro (Si este almacen no es el distrito sanitario asignado al suministro
                se lanzara una excepcion)
        @param idSuministro El identificador del suministro
        @param fecha La fecha en la que el suministro llego al almacen
    */
    function utilizarSuministro(address direccionAlmacen, uint idSuministro, uint fecha) external soloContratos puedeParar {
        require(perteneceSuministro(idSuministro), "Error 404: Suministro no encontrado");
        require(direccionAlmacen == informacionSuministro[idSuministro].distritoDestino, "Error 400: Distrito sanitario indicado no es su destino");

        string memory tipoSuministro = informacionSuministro[idSuministro].tipo;
        uint tamanoSuministro = informacionSuministro[idSuministro].tamano;

        contratoTrazabilidad.utilizarSuministro(direccionAlmacen, idSuministro, fecha);
        contratoAlmacenes.utilizarSuministro(idSuministro, direccionAlmacen,
            tipoSuministro, tamanoSuministro);
        informacionSuministro[idSuministro].utilizado = true;
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
        string memory suministrosJSON = '{"resultado":[';

        for (uint i=0; i<suministros.length; i++)
            if (i != (suministros.length-1))
                suministrosJSON = string(abi.encodePacked(suministrosJSON,Strings.toString(suministros[i]),','));
            else
                suministrosJSON = string(abi.encodePacked(suministrosJSON,Strings.toString(suministros[i])));

        suministrosJSON = string(abi.encodePacked(suministrosJSON,']}'));

        return (suministrosJSON);
    }

    /**
        @notice Devuelve contenido JSON con toda la informacion del suministro indicado
        @param idSuministro Identificador del suministro
        @return un JSON (string con contenido JSON) con toda la informacion del
                suministro indicado y con el siguiente formato:
                {
                    "id":"<idSuministro>",
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
        require(perteneceSuministro(idSuministro), "Error 404: Suministro no encontrado");

        suministro memory datosSuministro = informacionSuministro[idSuministro];
        address almacenActual = contratoTrazabilidad.getAlmacenSuministro(idSuministro);
        string memory comunidadAsignada = contratoAlmacenes.getComunidadAlmacen(datosSuministro.distritoDestino);

        string memory informacion = string(abi.encodePacked('{"id":',Strings.toString(idSuministro),',',
                                        '"tipo":"',datosSuministro.tipo,'",',
                                        '"tamano":',Strings.toString(datosSuministro.tamano),',',
                                        '"almacenActual":"',direccionAString(almacenActual),'",',
                                        '"comunidadAsignada":"',comunidadAsignada,'",',
                                        '"distritoDestino":"',direccionAString(datosSuministro.distritoDestino),'",'));

        bool enViaje = contratoTrazabilidad.enViajeSuministro(idSuministro);

        if (enViaje)
            informacion = string(abi.encodePacked(informacion,'"enViaje":true,'));
        else
            informacion = string(abi.encodePacked(informacion,'"enViaje":false,'));

        if (datosSuministro.utilizado)
            informacion = string(abi.encodePacked(informacion,'"utilizado":true}'));
        else
            informacion = string(abi.encodePacked(informacion,'"utilizado":false}'));

        return (informacion);
    }

}
