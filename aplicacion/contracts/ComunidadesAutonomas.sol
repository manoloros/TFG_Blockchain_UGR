pragma solidity 0.6.9;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./Privado.sol";
import "./Almacenes.sol";
import "./SuministrosMedicos.sol";
import "./AccesoBlockchain.sol";

/**
    @title Contrato que gestiona a las comunidades autonomas
    @author Manuel Ros Rodriguez
    @notice Contrato que se encarga de gestionar la funcionalidad relacionada
            con las comunidades autonomas
*/
contract ComunidadesAutonomas is Privado {

    struct comunidadAutonoma {
        uint poblacion;
        string informacion;
        bool esValido;
        mapping(string => uint) unidadesSuministro;
    }

    string[] private comunidades;
    mapping(string => comunidadAutonoma) private informacionComunidad;

    Almacenes private contratoAlmacenes;
    SuministrosMedicos private contratoSuministros;
    AccesoBlockchain private contratoAcceso;

    /*
        modificador que utilizamos en los metodos para que el contrato solo acepte llamadas
        al metodo enviadas por los contratos que conoce
    */
    modifier soloContratos {
        require(msg.sender == address(contratoAlmacenes) ||
                msg.sender == address(contratoAcceso), "Recibida llamada de contrato no autorizado");
        _;
    }

    /**
        @notice Cambia el contrato SuministrosMedicos con el que se comunica este contrato
        @param direccionSuministros La direccion del nuevo contrato SuministrosMedicos
    */
    function cambiarContratoSuministros(SuministrosMedicos direccionSuministros) external soloCuentaAutorizada soloParado {
        contratoSuministros = direccionSuministros;
    }

    /**
        @notice Cambia el contrato Almacenes con el que se comunica este contrato
        @param direccionAlmacenes La direccion del nuevo contrato Almacenes
    */
    function cambiarContratoAlmacenes(Almacenes direccionAlmacenes) external soloCuentaAutorizada soloParado {
        contratoAlmacenes = direccionAlmacenes;
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
        @param direccionSuministros La direccion del contrato SuministrosMedicos
        @param direccionAcceso La direccion del contrato AccesoBlockchain
    */
    function inicializar(Almacenes direccionAlmacenes, SuministrosMedicos direccionSuministros,
        AccesoBlockchain direccionAcceso) external soloCuentaAutorizada soloParado
    {
        contratoAlmacenes = direccionAlmacenes;
        contratoSuministros = direccionSuministros;
        contratoAcceso = direccionAcceso;
    }

    /**
        @notice Anade una nueva comunidad autonoma al sistema
        @param nombre Nombre de la comunidad autonoma (su identificador)
        @param informacion Informacion de la comunidad autonoma
    */
    function anadirComunidadAutonoma(string calldata nombre, string calldata informacion) external soloContratos puedeParar  {
        require(!perteneceComunidad(nombre), "Error 400: Comunidad autonoma ya incluida");

        comunidades.push(nombre);
        informacionComunidad[nombre] = comunidadAutonoma(0, informacion, true);
    }

    /**
        @notice Comprueba si la comunidad autonoma indicada esta incluida en el sistema
        @param nombre El nombre (identificador) de la comunidad autonoma
        @return si pertenece o no mediante un bool
    */
    function perteneceComunidad(string calldata nombre) public view puedeParar returns (bool) {
        if (!informacionComunidad[nombre].esValido)
            return false;
        else
            return true;
    }

    /**
        @notice Asigna al suministro que acaba de llegar a Espana una comunidad autonoma
                utilizando el siguiente criterio: Partiendo de la poblacion y las unidades
                de este tipo de suministro que tiene cada comunidad autonoma se escoge la
                comunidad autonoma con mayor necesidad
        @param tipoSuministro El tipo de suministro
        @return el nombre (identificador) de la comunidad autonoma asignada al
                suministro
    */
    function repartirComunidades(string calldata tipoSuministro) external view puedeParar returns (string memory) {
        int suministrosNecesariosMaximos = int(informacionComunidad[comunidades[0]].poblacion) -
                int(informacionComunidad[comunidades[0]].unidadesSuministro[tipoSuministro]);
        string memory comunidad = comunidades[0];

        for (uint i=0; i<comunidades.length; i++){
            int suministrosNecesarios = int(informacionComunidad[comunidades[i]].poblacion) -
                    int(informacionComunidad[comunidades[i]].unidadesSuministro[tipoSuministro]);
            if (suministrosNecesariosMaximos < suministrosNecesarios){
                suministrosNecesariosMaximos = suministrosNecesarios;
                comunidad = comunidades[i];
            }
        }

        return (comunidad);
    }

    /**
        @notice Anade un nuevo suministro al sistema (El suministro acaba de llegar a Espana)
        @param tipoSuministro El tipo de suministro que es
        @param tamanoSuministro La cantidad de unidades que incluye el suministro
        @param comunidad La comunidad autonoma a la que esta asignado
    */
    function registrarSuministro(string calldata tipoSuministro, uint tamanoSuministro,
        string calldata comunidad) external soloContratos puedeParar
    {
        informacionComunidad[comunidad].unidadesSuministro[tipoSuministro] += tamanoSuministro;
    }

    /**
        @notice Gestiona la apertura de un suministro
        @param tipoSuministro El tipo de suministro que es
        @param tamanoSuministro La cantidad de unidades que incluye el suministro
        @param comunidad El nombre (identificador) de la comunidad autonoma asignada
                al suministro
    */
    function utilizarSuministro(string calldata tipoSuministro, uint tamanoSuministro,
        string calldata comunidad) external soloContratos puedeParar
    {
        informacionComunidad[comunidad].unidadesSuministro[tipoSuministro] -= tamanoSuministro;
    }

    /**
        @notice Modifica la comunidad autonoma indicada
        @param nombre El nombre (identificador) de la comunidad autonoma
        @param informacion La informacion nueva que se le quiere asignar
    */
    function modificarComunidadAutonoma(string calldata nombre, string calldata informacion) external soloContratos puedeParar {
        require(perteneceComunidad(nombre), "Error 404: Comunidad autonoma no encontrada");
        informacionComunidad[nombre].informacion = informacion;
    }

    /**
        @notice Actualiza la poblacion de la comunidad autonoma indicada
        @param comunidad El nombre (identificador) de la comunidad autonoma
        @param diferenciaPoblacion El valor que hay que sumarle (o restarle) a la poblacion
    */
    function actualizarPoblacion(string calldata comunidad, int diferenciaPoblacion) external soloContratos puedeParar {
        // Convertimos la poblacion de la comunidad a tipo int para poder operar con diferenciaPoblacion y sabemos
        // que el resultado de la operacion siempre sera positivo, por lo que podemos volver a convertirlo en uint
        informacionComunidad[comunidad].poblacion = uint(int(informacionComunidad[comunidad].poblacion) + diferenciaPoblacion);
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
        string memory comunidadesJSON = '{"resultado":[';

        for (uint i=0; i<comunidades.length; i++)
            if (i != (comunidades.length-1))
                comunidadesJSON = string(abi.encodePacked(comunidadesJSON,'"',comunidades[i],'",'));
            else
                comunidadesJSON = string(abi.encodePacked(comunidadesJSON,'"',comunidades[i],'"'));

        comunidadesJSON = string(abi.encodePacked(comunidadesJSON,']}'));

        return (comunidadesJSON);
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
        require(perteneceComunidad(nombre), "Error 404: Comunidad no encontrada");

        comunidadAutonoma storage comunidad = informacionComunidad[nombre];

        string memory informacion = string(abi.encodePacked('{"nombre":"',nombre,'",',
                                        '"informacion":"',comunidad.informacion,'",',
                                        '"poblacion":',Strings.toString(comunidad.poblacion),',',
                                        '"distritos":['));


        address[] memory distritos = contratoAlmacenes.getDistritosComunidad(nombre);

        for (uint i=0; i<distritos.length; i++)
            if (i != (distritos.length-1))
                informacion = string(abi.encodePacked(informacion,'"',
                    direccionAString(distritos[i]),'",'));
            else
                informacion = string(abi.encodePacked(informacion,'"',
                    direccionAString(distritos[i]),'"'));

        informacion = string(abi.encodePacked(informacion,'],'));

        uint tamanoTipos = contratoSuministros.getTiposSuministroTamano();
        informacion = string(abi.encodePacked(informacion,'"tiposSuministro":{'));

        for (uint i=0; i<tamanoTipos; i++)
            if (i != (tamanoTipos-1))
                informacion = string(abi.encodePacked(informacion,'"',contratoSuministros.getTipoSuministroIndice(i),
                    '":',Strings.toString(comunidad.unidadesSuministro[contratoSuministros.getTipoSuministroIndice(i)]),
                    ','));
            else
                informacion = string(abi.encodePacked(informacion,'"',contratoSuministros.getTipoSuministroIndice(i),
                    '":',Strings.toString(comunidad.unidadesSuministro[contratoSuministros.getTipoSuministroIndice(i)])));

        informacion = string(abi.encodePacked(informacion,'}}'));

        return (informacion);
    }

}
