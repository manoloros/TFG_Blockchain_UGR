pragma solidity 0.6.9;

import "@openzeppelin/contracts/utils/Strings.sol";

/**
    @title Contrato con codigo comun al resto de contratos
    @author Manuel Ros Rodriguez
    @notice Permite que el contrato se pueda parar y deje de aceptar peticiones
            y que solo acepte peticiones de una cuenta especifica (cuenta autorizada)
*/
abstract contract Privado {
    address private cuentaAutorizada;
    bool private parado;

    /**
        @notice Inicializa variables, cuentaAutorizada sera la cuenta que subio el contrato
        a la blockchain (msg.sender) y los contratos empiezan bloqueados (parado = true)
    */
    constructor() public {
        cuentaAutorizada = msg.sender;
        parado = true;
    }

    /*
        modificador que utilizamos en los metodos para que el contrato solo acepte llamadas
        al metodo si la variable parado tiene valor false
    */
    modifier puedeParar {
        require(!parado, "El contrato se encuentra parado");
        _;
    }

    /*
        modificador que utilizamos en los metodos para que el contrato solo acepte llamadas
        al metodo si la variable parado tiene valor true
    */
    modifier soloParado {
        require(parado, "El contrato no se encuentra parado");
        _;
    }

    /*
        modificador que utilizamos en los metodos para que el contrato solo acepte llamadas
        al metodo enviadas por la cuenta autorizada
    */
    modifier soloCuentaAutorizada {
        require(msg.sender == cuentaAutorizada, "Cuenta utilizada no esta autorizada");
        _;
    }

    /**
        @notice Cambia la cuenta autorizada (cuenta que puede llamar a los metodos con modificador
                soloCuentaAutorizada)
        @param nuevaCuentaAutorizada La direccion de la nueva cuenta autorizada
    */
    function cambiarCuentaAutorizada(address nuevaCuentaAutorizada) external soloCuentaAutorizada {
        cuentaAutorizada = nuevaCuentaAutorizada;
    }

    /**
        @notice Devuelve la direccion de la cuenta autorizada
        @return La direccion de la cuenta autorizada
    */
    function getCuentaAutorizada() external view soloCuentaAutorizada returns (address) {
        return cuentaAutorizada;
    }

    /**
        @notice Hace que un contrato deje de aceptar llamadas a los metodos con modificador
                puedeParar y que empiece a aceptar llamadas a los metodos con modificador
                soloParado
    */
    function pararContrato() external soloCuentaAutorizada puedeParar {
        parado = true;
    }

    /**
        @notice Hace que un contrato deje de aceptar llamadas a los metodos con modificador
                soloParado y que empiece a aceptar llamadas a los metodos con modificador
                puedeParar
    */
    function continuarContrato() external soloCuentaAutorizada soloParado {
        parado = false;
    }

    /**
        @notice Convierte un tipo de dato address en un string
        @param direccion La direccion a convertir en string
        @return La direccion convertida en string
    */
    function direccionAString(address direccion) internal pure returns (string memory) {
        // El indice corresponde al valor decimal y la letra que se obtiene a su representacion hexadecimal
        string memory decimalHexadecimal = "0123456789abcdef";

        // Convertimos el tipo de dato address en bytes
        uint160 direccionUint = uint160(direccion);
        bytes20 direccionBytes = bytes20(direccionUint);

        string memory direccionString = "0x";

        // Recorremos byte a byte la variable direccionBytes
        for (uint i=0; i<direccionBytes.length; i++) {
            // Obtenemos los primeros 4 bits del byte y utilizamos su valor decimal como indice para acceder a letrasHexadecimal
            // y anadimos la letra obtenida al string
            direccionString = string(abi.encodePacked(direccionString, bytes(decimalHexadecimal)[uint8(direccionBytes[i] >> 4)]));

            // Obtenemos los ultimos 4 bits del byte y utilizamos su valor decimal como indice para acceder a letrasHexadecimal
            // y anadimos la letra obtenida al string
            direccionString = string(abi.encodePacked(direccionString, bytes(decimalHexadecimal)[uint8((direccionBytes[i] << 4) >> 4)]));
        }

        return (direccionString);
    }
}
