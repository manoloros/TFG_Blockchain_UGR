pragma solidity 0.6.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./SuministrosMedicos.sol";
import "./AccesoBlockchain.sol";
import "./Privado.sol";

/**
    @title Contrato que gestiona la trazabilidad de los suministros medicos
    @author Manuel Ros Rodriguez
    @notice Contrato que se encarga de gestionar la funcionalidad relacionada
            con la trazabilidad de los suministros medicos
*/
contract TrazabilidadSuministros is Privado {
    struct informacionTrazabilidad {
        bool enViaje;
        address direccionAlmacenOrigen;
        uint fechaSalida;
        address direccionAlmacenDestino;
        uint fechaEntrada;
    }

    mapping(uint => informacionTrazabilidad[]) private trazabilidadSuministro;

    SuministrosMedicos private contratoSuministros;
    AccesoBlockchain private contratoAcceso;

    /*
        modificador que utilizamos en los metodos para que el contrato solo acepte llamadas
        al metodo enviadas por los contratos que conoce
    */
    modifier soloContratos {
        require(msg.sender == address(contratoSuministros) ||
                msg.sender == address(contratoAcceso), "Recibida llamada de contrato no autorizado");
        _;
    }

    /**
        @notice Cambia el contrato AccesoBlockchain del que recibe llamadas
        @param direccionAcceso La direccion del nuevo contrato AccesoBlockchain
    */
    function cambiarContratoAcceso(AccesoBlockchain direccionAcceso) external soloCuentaAutorizada soloParado {
        contratoAcceso = direccionAcceso;
    }

    /**
        @notice Cambia el contrato SuministrosMedicos con el que se comunica este contrato
        @param direccionSuministros La direccion del nuevo contrato SuministrosMedicos
    */
    function cambiarContratoSuministros(SuministrosMedicos direccionSuministros) external soloCuentaAutorizada soloParado {
        contratoSuministros = direccionSuministros;
    }

    /**
        @notice Inicializa el contrato, asignandole las direcciones de los contratos con los que interactuara
        @param direccionSuministros La direccion del contrato SuministrosMedicos
        @param direccionAcceso La direccion del contrato AccesoBlockchain
    */
    function inicializar(SuministrosMedicos direccionSuministros, AccesoBlockchain direccionAcceso) external soloCuentaAutorizada soloParado {
        contratoSuministros = direccionSuministros;
        contratoAcceso = direccionAcceso;
    }

    /**
        @notice Anade un nuevo suministro al sistema (El suministro acaba de llegar a Espana)
        @param idSuministro El identificador del suministro
        @param almacenInicio Direccion (identificador) del almacen en el que se encuentra el
                suministro
        @param fecha La fecha en la que llego al almacen almacenInicio
    */
    function registrarSuministro(uint idSuministro, address almacenInicio, uint fecha) external soloContratos puedeParar  {
        trazabilidadSuministro[idSuministro].push(informacionTrazabilidad(false, address(0), 0, almacenInicio, fecha));
    }

    /**
        @notice Gestiona la salida de un suministro de un almacen
        @param origen Direccion (identificador) del almacen del que ha salido
        @param idSuministro El identificador del suministro
        @param fecha La fecha en la que el suministro salio del almacen
    */
    function notificarSalidaAlmacen(address origen, uint idSuministro, uint fecha) external soloContratos puedeParar  {
        trazabilidadSuministro[idSuministro].push(informacionTrazabilidad(true, origen, fecha, address(0), 0));
    }

    /**
        @notice Devuelve si el suministro indicado esta de viaje (ha notificado la salida
                de un almacen pero no ha notificado la llegada a otro)
        @param idSuministro El identificador del suministro
        @return si el suministro indicado esta de viaje (ha notificado la salida
                de un almacen pero no ha notificado la llegada a otro) o no mediante un bool
    */
    function enViajeSuministro(uint idSuministro) public view puedeParar returns (bool) {
        uint length = trazabilidadSuministro[idSuministro].length;
        return (trazabilidadSuministro[idSuministro][length-1].enViaje);
    }

    /**
        @notice Gestiona la llegada de un suministro a un almacen
        @param destino Direccion (identificador) del almacen al que ha llegado el suministro
        @param idSuministro El identificador del suministro (El suministro debe de haber notificado
                su salida previamente)
        @param fecha La fecha en la que el suministro llego al almacen
    */
    function notificarLlegadaAlmacen(address destino, uint idSuministro, uint fecha) external soloContratos puedeParar  {
        require(enViajeSuministro(idSuministro), "Error 400: Suministro no ha salido del almacen");

        uint length = trazabilidadSuministro[idSuministro].length;
        trazabilidadSuministro[idSuministro][length-1].direccionAlmacenDestino = destino;
        trazabilidadSuministro[idSuministro][length-1].fechaEntrada = fecha;
        trazabilidadSuministro[idSuministro][length-1].enViaje = false;
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
        trazabilidadSuministro[idSuministro].push(informacionTrazabilidad(false, direccionAlmacen, fecha, address(0), 0));
    }

    /**
        @notice Devuelve el almacen en el que se encuentra almacenado el suministro, en el caso
                de que este en viaje se devuelve el ultimo almacen en el que estuvo
        @param idSuministro El identificador del suministro
        @return el almacen en el que se encuentra almacenado el suministro, en el caso
                de que este en viaje se devuelve el ultimo almacen en el que estuvo
    */
    function getAlmacenSuministro(uint idSuministro) external view puedeParar returns (address) {
        informacionTrazabilidad[] memory trazabilidad = trazabilidadSuministro[idSuministro];

        if (trazabilidad[trazabilidad.length-1].direccionAlmacenDestino == address(0))
            return (trazabilidad[trazabilidad.length-1].direccionAlmacenOrigen);
        else
            return (trazabilidad[trazabilidad.length-1].direccionAlmacenDestino);
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
        require(contratoSuministros.perteneceSuministro(idSuministro), "Error 404: Suministro no encontrado");

        informacionTrazabilidad[] memory trazabilidad = trazabilidadSuministro[idSuministro];
        string memory trazabilidadJSON = '{"resultado":[';

        for (uint i=0; i<trazabilidad.length; i++)
            if (i != (trazabilidad.length-1))
                trazabilidadJSON = string(abi.encodePacked(trazabilidadJSON,'{"almacenOrigen":"',
                    direccionAString(trazabilidad[i].direccionAlmacenOrigen),'","almacenDestino":"',
                    direccionAString(trazabilidad[i].direccionAlmacenDestino),'","fechaSalida":',
                    Strings.toString(trazabilidad[i].fechaSalida),',"fechaEntrada":',
                    Strings.toString(trazabilidad[i].fechaEntrada),'},'));
            else
                trazabilidadJSON = string(abi.encodePacked(trazabilidadJSON,'{"almacenOrigen":"',
                    direccionAString(trazabilidad[i].direccionAlmacenOrigen),'","almacenDestino":"',
                    direccionAString(trazabilidad[i].direccionAlmacenDestino),'","fechaSalida":',
                    Strings.toString(trazabilidad[i].fechaSalida),',"fechaEntrada":',
                    Strings.toString(trazabilidad[i].fechaEntrada),'}'));


        trazabilidadJSON = string(abi.encodePacked(trazabilidadJSON,']}'));

        return (trazabilidadJSON);
    }


}
